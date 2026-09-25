import Foundation
import SmartPasteCore

extension SmartPastePath {
    /// The path in the outcome log line: its name, and Jev's free-text probability with two decimals when a
    /// decision arrived — `via=freeTextTarget p=0.93`, `via=jev p=0.12`, `via=jev`, `via=directPaste`.
    var logFragment: String {
        switch self {
        case .jev(let probability): "via=jev" + (probability.map(Self.probabilityFragment) ?? "")
        case .freeTextTarget(let probability): "via=freeTextTarget" + Self.probabilityFragment(probability)
        case .directPaste: "via=directPaste"
        }
    }

    private static func probabilityFragment(_ probability: Double) -> String {
        String(format: " p=%.2f", probability)
    }
}
