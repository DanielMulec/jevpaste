import Foundation
import JevGateway
import SmartPasteCore

/// A transport that never touches the network: it records every request and answers with a canned outcome.
actor StubTransport: HTTPTransport {
    enum Outcome: Sendable {
        case response(status: Int, headers: [String: String], body: Data)
        case transportError
    }

    struct TransportError: Error {}

    private(set) var sentRequests: [URLRequest] = []
    private let outcome: Outcome

    init(_ outcome: Outcome) {
        self.outcome = outcome
    }

    static func answering(status: Int = 200, headers: [String: String] = [:], body: String) -> StubTransport {
        StubTransport(.response(status: status, headers: headers, body: Data(body.utf8)))
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        sentRequests.append(request)
        switch outcome {
        case .transportError:
            throw TransportError()
        case .response(let status, let headers, let body):
            guard
                let url = request.url,
                let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: headers)
            else { throw TransportError() }
            return (body, response)
        }
    }
}

enum Fixture {
    /// One step-1 question in the excerpt-id form over Ada's card: everything, three excerpts, nothing, ask.
    static let request = NarrowingRequest(
        sourceDocument: "Name: Ada Lovelace\nEmail: ada@example.org\nCity: London",
        targetContext: TargetContext(
            fieldLabel: "Email address",
            placeholder: "you@example.com",
            sectionHeading: "Contact",
            siblingFieldLabels: ["Full name"],
            surroundingText: "Sign up for the newsletter"
        ),
        excerpts: [
            NarrowingExcerpt(id: "x0000", text: "Ada Lovelace"), NarrowingExcerpt(id: "x0001", text: "ada@example.org"),
            NarrowingExcerpt(id: "x0002", text: "London"),
        ],
        questions: [
            ChoiceQuestion(
                id: "narrow_0", instructions: .wholeCopy("Choose."),
                options: ["everything", "x0000", "x0001", "x0002", "nothing_fits", "ask_user"].map { id in
                    ChoiceOption(id: id, description: id.hasPrefix("x") ? .excerpt : .text("The \(id) option."))
                }
            )
        ]
    )

    static let keyFileText = "AI_GATEWAY_API_KEY=test-key-value\n"

    /// A Jev answer in the shape the spike recorded (`round2/results/raw.jsonl`), reduced to the fields the adapter
    /// reads plus some noise; probabilities deliberately not in option order.
    static func evaluateResponse(choice: String, probability: Double = 0.97) -> String {
        """
        {"answers":{"narrow_0":{"type":"choice","choice":"\(choice)",
          "probabilities":{"x0002":0,"\(choice)":\(probability),"ask_user":0.01},"confidence":0.96}},
         "model":"typesafe-ai/jev","usage":{"inputTokens":800,"outputTokens":60}}
        """
    }

    static func keyFile(containing text: String) throws -> URL {
        let file = FileManager.default.temporaryDirectory.appending(path: "jevgateway-\(UUID().uuidString).env")
        try Data(text.utf8).write(to: file)
        return file
    }

    static func service(
        transport: StubTransport,
        keyFileText: String = keyFileText
    ) throws -> JevGatewayDecisionService {
        let credentials = GatewayCredentials(envFile: try keyFile(containing: keyFileText))
        return JevGatewayDecisionService(credentials: credentials, transport: transport)
    }
}

/// Starts one request through the seam and waits for its single reply.
func reply(
    from service: JevGatewayDecisionService,
    to request: NarrowingRequest = Fixture.request
) async -> NarrowingReply {
    await withCheckedContinuation { continuation in
        service.evaluate(request) { narrowingReply in
            MainActor.assertIsolated()
            continuation.resume(returning: narrowingReply)
        }
    }
}
