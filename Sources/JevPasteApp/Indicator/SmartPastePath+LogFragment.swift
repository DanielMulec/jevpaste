import Foundation
import SmartPasteCore

extension SmartPastePath {
    /// The path in the outcome log line: its name, Jev's free-text probability with two decimals when a decision
    /// arrived, and how a No Suitable Match offer ended — `via=freeTextTarget p=0.93`, `via=jev p=0.12`, `via=jev`,
    /// `via=directPaste`. An accepted offer is a Direct Paste with its reason (`via=directPaste
    /// reason=enterAfterNoMatch p=0.12`); one that ended without Enter stays on the Jev path (`via=jev p=0.12
    /// offer=dismissed`, `offer=timedOut`). Fixed names and numbers only.
    var logFragment: String {
        switch self {
        case .jev(let probability, offer: .accepted):
            "via=directPaste reason=enterAfterNoMatch" + Self.probabilityFragment(probability)
        case .jev(let probability, let offer):
            "via=jev" + Self.probabilityFragment(probability) + (offer.map { " offer=\($0)" } ?? "")
        case .freeTextTarget(let probability): "via=freeTextTarget" + Self.probabilityFragment(probability)
        case .directPaste: "via=directPaste"
        }
    }

    private static func probabilityFragment(_ probability: Double?) -> String {
        probability.map { String(format: " p=%.2f", $0) } ?? ""
    }
}
