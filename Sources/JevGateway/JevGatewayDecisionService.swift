import Foundation
import SmartPasteCore
import os

/// The `DecisionService` adapter that asks Jev through one Jev Provider: one `POST` to the provider's endpoint per
/// Narrowing request, with all of its choice questions, answered once on the main actor. It holds the provider and
/// the key read when the Paste Attempt opened it (`JevGatewayAccess`); what differs per provider is `JevEndpoint`.
///
/// No retry, no timeout and no size limit of its own — the Paste Attempt owns the first two, Jev enforces the third.
/// Diagnostics carry status, counts, bytes and latency only; never the key, the source document, the Target Context
/// or any excerpt.
public struct JevGatewayDecisionService: DecisionService {
    private static let log = Logger(subsystem: "jevpaste", category: "JevGateway")

    private let provider: JevProvider
    private let endpoint: JevEndpoint
    private let apiKey: String
    private let transport: any HTTPTransport

    public init(provider: JevProvider, apiKey: String, transport: any HTTPTransport = URLSessionTransport()) {
        self.provider = provider
        endpoint = JevEndpoint.of(provider)
        self.apiKey = apiKey
        self.transport = transport
    }

    public func evaluate(_ request: NarrowingRequest, reply: @escaping @MainActor @Sendable (NarrowingReply) -> Void) {
        evaluateReportingStatus(request) { narrowingReply, _ in reply(narrowingReply) }
    }

    /// `evaluate`, also passing on the HTTP status the reply came from (`nil` when no response arrived) — what
    /// Settings' connection test tells the user.
    func evaluateReportingStatus(
        _ request: NarrowingRequest, reply: @escaping @MainActor @Sendable (NarrowingReply, Int?) -> Void
    ) {
        Task {
            let started = ContinuousClock.now
            let body = EvaluateRequestBody.data(for: request, model: endpoint.model)
            let exchanged = await exchange(request, body: body)
            logReply(exchanged, request: request, bytes: body.count, after: .now - started)
            await reply(exchanged.reply, exchanged.status)
        }
    }

    /// What one request came back with: the reply, the HTTP status (`nil` when no response arrived) and, on a 200,
    /// the model that answered.
    private struct Exchanged {
        let reply: NarrowingReply
        let status: Int?
        var answeredModel: String?
    }

    private func exchange(_ request: NarrowingRequest, body: Data) async -> Exchanged {
        guard let (responseBody, response) = try? await transport.send(urlRequest(body: body))
        else { return Exchanged(reply: Self.failed(.transport), status: nil) }
        let status = response.statusCode
        switch status {
        case 200:
            let model = EvaluateResponse.answeredModel(in: responseBody)
            switch EvaluateResponse.answers(from: responseBody, to: request) {
            case .success(let answers):
                return Exchanged(reply: .answered(answers), status: status, answeredModel: model)
            case .failure(let failure):
                return Exchanged(reply: Self.failed(failure), status: status, answeredModel: model)
            }
        case 429, endpoint.overloadStatus:
            return Exchanged(reply: .rateLimited(retryAfter: RateLimit.retryAfter(of: response)), status: status)
        case 400 where JevRefusal.isTooLarge(responseBody):
            return Exchanged(reply: .tooLarge, status: status)
        default:
            return Exchanged(reply: Self.failed(.httpStatus(status)), status: status)
        }
    }

    private static func failed(_ failure: JevGatewayFailure) -> NarrowingReply {
        log.error("Jev request failed: \(String(describing: failure), privacy: .public)")
        return .failed
    }

    private func urlRequest(body: Data) -> URLRequest {
        var urlRequest = URLRequest(url: endpoint.url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer " + apiKey, forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = body
        return urlRequest
    }

    /// `Jev answered provider=typesafeDirect status=200 model=jev-1.13.0 questions=2 options=510 bytes=41234 in 0.61
    /// seconds` — the provider, numbers, a model id and fixed words only.
    private func logReply(_ exchanged: Exchanged, request: NarrowingRequest, bytes: Int, after latency: Duration) {
        let outcome: String
        switch exchanged.reply {
        case .answered: outcome = "answered"
        case .rateLimited(let retryAfter): outcome = "rate limited, retry after \(retryAfter)"
        case .tooLarge: outcome = "refused the size"
        case .failed: outcome = "failed"
        }
        let statusText = exchanged.status.map(String.init) ?? "none"
        let model = exchanged.answeredModel ?? "none"
        let options = request.questions.reduce(0) { $0 + $1.options.count }
        let elapsed = String(describing: latency)
        Self.log.info(
            """
            Jev \(outcome, privacy: .public) provider=\(provider.rawValue, privacy: .public) \
            status=\(statusText, privacy: .public) model=\(model, privacy: .public) \
            questions=\(request.questions.count) options=\(options) bytes=\(bytes) in \(elapsed, privacy: .public)
            """
        )
    }
}
