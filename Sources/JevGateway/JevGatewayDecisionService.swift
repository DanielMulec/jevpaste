import Foundation
import SmartPasteCore
import os

/// The `DecisionService` adapter that asks Jev through the Vercel AI Gateway: one batched `POST /v1/evaluate`
/// per request, answered once on the main actor.
///
/// No retry and no timeout of its own — the Paste Attempt owns both. Diagnostics carry status, counts and
/// latency only; never the key, the source document, the Target Context or the Candidates.
public struct JevGatewayDecisionService: DecisionService {
    private static let endpoint: URL = {
        guard let url = URL(string: "https://ai-gateway.vercel.sh/v1/evaluate") else {
            preconditionFailure("The Jev evaluate endpoint literal is a valid URL")
        }
        return url
    }()
    private static let log = Logger(subsystem: "jevpaste", category: "JevGateway")

    private let credentials: GatewayCredentials
    private let transport: any HTTPTransport

    public init(credentials: GatewayCredentials = .standard, transport: any HTTPTransport = URLSessionTransport()) {
        self.credentials = credentials
        self.transport = transport
    }

    public func requestDecision(
        _ request: DecisionRequest,
        reply: @escaping @MainActor @Sendable (DecisionReply) -> Void
    ) {
        Task {
            let started = ContinuousClock.now
            let decisionReply = await decide(request)
            Self.logReply(decisionReply, optionCount: request.candidates.count, after: .now - started)
            await reply(decisionReply)
        }
    }

    private func decide(_ request: DecisionRequest) async -> DecisionReply {
        switch await exchange(request) {
        case .failure(let failure):
            Self.log.error("Jev request failed: \(String(describing: failure), privacy: .public)")
            return .failed
        case .success(let reply):
            return reply
        }
    }

    private func exchange(_ request: DecisionRequest) async -> Result<DecisionReply, JevGatewayFailure> {
        guard request.candidates.count <= EvaluateRequestBody.maximumCandidateCount else {
            return .failure(.tooManyCandidates(count: request.candidates.count))
        }
        guard let apiKey = credentials.apiKey() else {
            return .failure(.missingKey(file: credentials.envFile.path(percentEncoded: false)))
        }
        guard let urlRequest = Self.urlRequest(for: request, apiKey: apiKey) else {
            return .failure(.malformedRequest)
        }
        guard let (body, response) = try? await transport.send(urlRequest) else { return .failure(.transport) }
        switch response.statusCode {
        case 200:
            return EvaluateResponse.decision(from: body, offered: request.candidates).map(DecisionReply.decided)
        case 429:
            return .success(.rateLimited(retryAfter: RateLimit.retryAfter(of: response)))
        default:
            return .failure(.httpStatus(response.statusCode))
        }
    }

    private static func urlRequest(for request: DecisionRequest, apiKey: String) -> URLRequest? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        guard let body = try? encoder.encode(EvaluateRequestBody(request)) else { return nil }
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer " + apiKey, forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = body
        return urlRequest
    }

    private static func logReply(_ reply: DecisionReply, optionCount: Int, after latency: Duration) {
        let outcome: String
        switch reply {
        case .decided: outcome = "decided"
        case .rateLimited(let retryAfter): outcome = "rate limited, retry after \(retryAfter)"
        case .failed: outcome = "failed"
        }
        let elapsed = String(describing: latency)
        log.info("Jev \(outcome, privacy: .public) over \(optionCount) options in \(elapsed, privacy: .public)")
    }
}
