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
    static let candidates = ["Ada Lovelace", "ada@example.org", "London"].map(Candidate.init(text:))

    static let request = DecisionRequest(
        sourceDocument: "Name: Ada Lovelace\nEmail: ada@example.org\nCity: London",
        targetContext: TargetContext(
            fieldLabel: "Email address",
            placeholder: "you@example.com",
            sectionHeading: "Contact",
            siblingFieldLabels: ["Full name"],
            surroundingText: "Sign up for the newsletter"
        ),
        candidates: candidates
    )

    static let keyFileText = "AI_GATEWAY_API_KEY=test-key-value\n"

    /// A Jev answer in the shape the spikes recorded, reduced to the fields the adapter reads plus some noise.
    static func evaluateResponse(choice: String, containsValue: Double, freeText: Double = 0) -> String {
        """
        {"model":"typesafe-ai/jev","answers":{
          "paste":{"type":"choice","choice":"\(choice)","probabilities":{"\(choice)":1},"confidence":1},
          "contains_value":{"type":"boolean","probability":\(containsValue)},
          "free_text":{"type":"boolean","probability":\(freeText)}},
         "usage":{"inputTokens":800,"outputTokens":200}}
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
    to request: DecisionRequest = Fixture.request
) async -> DecisionReply {
    await withCheckedContinuation { continuation in
        service.requestDecision(request) { decisionReply in
            MainActor.assertIsolated()
            continuation.resume(returning: decisionReply)
        }
    }
}
