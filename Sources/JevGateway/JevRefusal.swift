import Foundation
import SmartPasteCore

/// Recognises Jev refusing a request's size: HTTP 400 whose body carries `{"error_type":"max_tokens_exceeded"}` —
/// as the Gateway's error message itself, or, in its fallback form ("typesafe returned status 400"), as the error of
/// one of its provider attempts; TypeSafe's own body is that object. Both Gateway forms were recorded by the
/// Narrowing spike (`results/raw.jsonl`, cell `N04_probe`).
enum JevRefusal {
    static let tooLargeErrorType = "max_tokens_exceeded"

    static func isTooLarge(_ body: Data) -> Bool {
        guard let json = OrderedJSONParser.parse(body) else { return false }
        let error = json["error"]
        let attempts = json["providerMetadata"]?["gateway"]?["routing"]?["modelAttempts"]?.arrayElements ?? []
        let providerErrors = attempts.flatMap { $0["providerAttempts"]?.arrayElements ?? [] }.map { $0["error"] }
        let places = [json, error?["message"], error?["param"]?["error"]] + providerErrors
        return places.contains { $0.map(namesTooLarge) == true }
    }

    /// `{"error_type": "max_tokens_exceeded"}` itself, or a string holding it (the Gateway nests TypeSafe's body).
    private static func namesTooLarge(_ place: OrderedJSON) -> Bool {
        if let text = place.stringValue {
            return OrderedJSONParser.parse(Data(text.utf8)).map(namesTooLarge) == true
        }
        return place["error_type"]?.stringValue == tooLargeErrorType
    }
}
