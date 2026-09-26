import Foundation
import SmartPasteCore
import os

/// The `DecisionService` adapter that asks Jev through the Vercel AI Gateway: one `POST /v1/evaluate` per Narrowing
/// request, with all of its choice questions, answered once on the main actor. It holds the key read when the Paste
/// Attempt opened the Jev Provider (`JevGatewayAccess`).
///
/// No retry, no timeout and no size limit of its own — the Paste Attempt owns the first two, Jev enforces the third.
/// Diagnostics carry status, counts, bytes and latency only; never the key, the source document, the Target Context
/// or any excerpt.
public struct JevGatewayDecisionService: DecisionService {
    private static let endpoint: URL = {
        guard let url = URL(string: "https://ai-gateway.vercel.sh/v1/evaluate") else {
            preconditionFailure("The Jev evaluate endpoint literal is a valid URL")
        }
        return url
    }()
    private static let log = Logger(subsystem: "jevpaste", category: "JevGateway")

    private let apiKey: String
    private let transport: any HTTPTransport

    public init(apiKey: String, transport: any HTTPTransport = URLSessionTransport()) {
        self.apiKey = apiKey
        self.transport = transport
    }

    public func evaluate(_ request: NarrowingRequest, reply: @escaping @MainActor @Sendable (NarrowingReply) -> Void) {
        Task {
            let started = ContinuousClock.now
            let body = EvaluateRequestBody.data(for: request)
            let (narrowingReply, status) = await exchange(request, body: body)
            Self.logReply(narrowingReply, status: status, request: request, bytes: body.count, after: .now - started)
            await reply(narrowingReply)
        }
    }

    /// The reply and the HTTP status it came from (`nil` when no response arrived).
    private func exchange(_ request: NarrowingRequest, body: Data) async -> (NarrowingReply, Int?) {
        guard let (responseBody, response) = try? await transport.send(Self.urlRequest(body: body, apiKey: apiKey))
        else { return (Self.failed(.transport), nil) }
        let status = response.statusCode
        switch status {
        case 200:
            switch EvaluateResponse.answers(from: responseBody, to: request) {
            case .success(let answers): return (.answered(answers), status)
            case .failure(let failure): return (Self.failed(failure), status)
            }
        case 429:
            return (.rateLimited(retryAfter: RateLimit.retryAfter(of: response)), status)
        case 400 where JevRefusal.isTooLarge(responseBody):
            return (.tooLarge, status)
        default:
            return (Self.failed(.httpStatus(status)), status)
        }
    }

    private static func failed(_ failure: JevGatewayFailure) -> NarrowingReply {
        log.error("Jev request failed: \(String(describing: failure), privacy: .public)")
        return .failed
    }

    private static func urlRequest(body: Data, apiKey: String) -> URLRequest {
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer " + apiKey, forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = body
        return urlRequest
    }

    /// `Jev answered status=200 questions=2 options=510 bytes=41234 in 0.61 seconds` — numbers and fixed words only.
    private static func logReply(
        _ reply: NarrowingReply, status: Int?, request: NarrowingRequest, bytes: Int, after latency: Duration
    ) {
        let outcome: String
        switch reply {
        case .answered: outcome = "answered"
        case .rateLimited(let retryAfter): outcome = "rate limited, retry after \(retryAfter)"
        case .tooLarge: outcome = "refused the size"
        case .failed: outcome = "failed"
        }
        let statusText = status.map(String.init) ?? "none"
        let options = request.questions.reduce(0) { $0 + $1.options.count }
        let elapsed = String(describing: latency)
        log.info(
            """
            Jev \(outcome, privacy: .public) status=\(statusText, privacy: .public) \
            questions=\(request.questions.count) options=\(options) bytes=\(bytes) in \(elapsed, privacy: .public)
            """
        )
    }
}
