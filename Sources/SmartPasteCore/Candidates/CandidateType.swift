/// The kind of value a Candidate holds, detected on its whole text. Two or more Candidates of one type make the
/// Target ambiguous, so the Candidate Chooser asks instead of guessing.
///
/// Checked in declaration order; the first match wins, so a text has at most one type.
enum CandidateType: CaseIterable {
    case email
    case url
    case handle
    case phone

    /// The type of `text` as a whole, or `nil` when it is none of them.
    init?(of text: String) {
        guard let type = Self.allCases.first(where: { $0.matchesWhole(text) }) else { return nil }
        self = type
    }

    private func matchesWhole(_ text: String) -> Bool {
        switch self {
        case .email:
            text.wholeMatch(of: /[A-Z0-9._%+\-]+@[A-Z0-9\-]+(\.[A-Z0-9\-]+)*\.[A-Z]{2,}/.ignoresCase()) != nil
        case .url:
            text.wholeMatch(of: /(https?:\/\/|www\.)\S+/.ignoresCase()) != nil
        case .handle:
            text.wholeMatch(of: /@[A-Z0-9_]{1,30}/.ignoresCase()) != nil
        case .phone:
            Self.isPhoneNumber(text)
        }
    }

    /// Digit groups joined by at most one separator (space, `.`, `/`, `-`), optionally with a leading `+` and
    /// parenthesised groups; 7–15 digits. Without a `+`, it also needs three groups or ten digits, so year ranges
    /// such as `2021-2024` and short numbers are not phones.
    private static func isPhoneNumber(_ text: String) -> Bool {
        let group = /(\([0-9]+\)|[0-9]+)/
        guard text.wholeMatch(of: /\+?\(?[0-9]+\)?([ .\/\-]?\(?[0-9]+\)?)*/) != nil else { return false }
        let digitCount = text.filter(\.isASCIIDigit).count
        let groupCount = text.matches(of: group).count
        return (7...15).contains(digitCount) && (text.hasPrefix("+") || groupCount >= 3 || digitCount >= 10)
    }
}

extension Character {
    fileprivate var isASCIIDigit: Bool { ("0"..."9").contains(self) }
}
