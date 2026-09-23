import SmartPasteCore

/// What the Candidate Chooser displays: a title from the Target Context and one row per Candidate, in the order
/// Core offered them. Display only — the chooser always replies with the untouched `Candidate`, never a row.
struct ChooserContent: Equatable {
    let title: String
    let rows: [String]

    init(candidates: [Candidate], context: TargetContext) {
        title = Self.title(for: context)
        rows = candidates.map { Self.row(for: $0.text) }
    }

    /// Names the field by its label, else its placeholder; plain "Which one?" when it has neither.
    private static func title(for context: TargetContext) -> String {
        let name = [context.fieldLabel, context.placeholder]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
        return name.map { "Which one for “\($0)”?" } ?? "Which one?"
    }

    /// A single-line Candidate verbatim; a multi-line one as its first line and its line count.
    private static func row(for text: String) -> String {
        let lines = text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
        guard lines.count > 1, let firstLine = lines.first else { return text }
        return "\(firstLine) … \(lines.count) lines"
    }
}
