import Foundation
import SmartPasteCore

/// The spike's cells (`Fixtures/narrowing-cells.jsonl`, written by `scripts/extract-narrowing-fixtures.py`): every
/// round-1 and round-2 copy that fits one request, its Target Context, and the excerpts the spike expected from it.
/// Synthetic data.
struct NarrowingCell: Decodable {
    let id: String
    let item: String
    /// The expected excerpt and the other accepted ones; empty for trap cells.
    let targets: [String]
    private let context: WireContext

    var targetContext: TargetContext {
        TargetContext(
            fieldLabel: context.fieldLabel, placeholder: context.placeholder, sectionHeading: context.sectionHeading,
            siblingFieldLabels: context.siblingFieldLabels ?? [], surroundingText: context.surroundingText ?? "",
            appName: context.appName, windowTitle: context.windowTitle
        )
    }

    static let all: [NarrowingCell] = {
        guard
            let url = Bundle.module.url(
                forResource: "narrowing-cells", withExtension: "jsonl", subdirectory: "Fixtures"
            ),
            let text = try? String(contentsOf: url, encoding: .utf8)
        else { return [] }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return text.split(separator: "\n").compactMap { try? decoder.decode(Self.self, from: Data($0.utf8)) }
    }()

    static func named(_ id: String) -> NarrowingCell? {
        all.first { $0.id == id }
    }
}

/// `target_context` as the spike wrote it, its snake-case keys converted.
private struct WireContext: Decodable {
    let appName: String?
    let windowTitle: String?
    let fieldLabel: String?
    let placeholder: String?
    let sectionHeading: String?
    let siblingFieldLabels: [String]?
    let surroundingText: String?
}
