import Foundation
import SmartPasteCore

/// The provider table: everything that differs between the Jev Providers on the wire. The request path, the encoding,
/// the parsing and the rest of the status mapping are shared (docs/design/jev-gateway.md).
struct JevEndpoint: Equatable {
    /// Where the evaluation is posted.
    let url: URL
    /// The `model` sent — pinned, because Core's thresholds were calibrated against Jev 1.13.0.
    let model: String
    /// A status meaning "overloaded, retry shortly" that becomes `.rateLimited` like a 429; `nil` when none is known.
    let overloadStatus: Int?

    /// Exhaustive on purpose: a new provider does not compile until it has its row here.
    static func of(_ provider: JevProvider) -> JevEndpoint {
        switch provider {
        case .vercelAIGateway:
            JevEndpoint(
                url: url("https://ai-gateway.vercel.sh/v1/evaluate"), model: "typesafe-ai/jev", overloadStatus: nil)
        case .typesafeDirect:
            JevEndpoint(url: url("https://api.typesafe.ai/v1/systemone"), model: "jev-1.13.0", overloadStatus: 529)
        }
    }

    private static func url(_ literal: String) -> URL {
        guard let url = URL(string: literal) else { preconditionFailure("The endpoint literal \(literal) is a URL") }
        return url
    }
}
