import Foundation
import SmartPasteCore

/// The JSON body of one `POST /v1/evaluate`: the model, then Core's `state` and `questions` exactly as Core rendered
/// them (member order kept) — the adapter adds nothing to what Jev reads.
enum EvaluateRequestBody {
    static let model = "typesafe-ai/jev"

    static func data(for request: NarrowingRequest) -> Data {
        let body = OrderedJSON.object([
            .init("model", .string(model)), .init("state", request.stateJSON),
            .init("questions", request.questionsJSON),
        ])
        return Data(body.rendered.utf8)
    }
}
