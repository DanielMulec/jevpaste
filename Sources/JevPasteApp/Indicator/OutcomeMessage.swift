import SmartPasteCore

/// What the indicator displays: one SF Symbol and one short line of text.
struct IndicatorContent: Equatable {
    let symbolName: String
    let text: String

    private static let cancelHint = " click to cancel"

    /// While Jev is choosing; the click hint appears only when a click actually cancels.
    static func processing(cancellable: Bool) -> IndicatorContent {
        IndicatorContent(symbolName: "ellipsis.circle", text: "Jev is choosing…" + (cancellable ? cancelHint : ""))
    }

    /// While waiting to retry after Jev asked us to; the click hint appears only when a click actually cancels.
    static func retrying(cancellable: Bool) -> IndicatorContent {
        IndicatorContent(symbolName: "hourglass", text: "Jev asked us to wait…" + (cancellable ? cancelHint : ""))
    }
}

/// The visible form of a Paste Attempt outcome: ✓ for a second on success, otherwise the reason for 2.5 s.
struct OutcomeMessage: Equatable {
    let content: IndicatorContent
    let displayDuration: Duration

    private static let successDuration = Duration.seconds(1)
    private static let reasonDuration = Duration.milliseconds(2500)

    /// Shown instead of "Cancelled" when the interim Candidate Chooser declined to choose among several matches.
    static let chooserNotBuilt = OutcomeMessage(
        reason: IndicatorContent(symbolName: "list.bullet.circle", text: "Several matches — chooser not built yet")
    )

    init(_ outcome: PasteAttemptOutcome) {
        switch outcome {
        case .inserted:
            self.init(
                content: IndicatorContent(symbolName: "checkmark.circle.fill", text: "Pasted"),
                displayDuration: Self.successDuration
            )
        case .insertedWithoutRestore:
            self.init(
                reason: IndicatorContent(
                    symbolName: "checkmark.circle",
                    text: "Pasted — original clipboard not restored (replaced by your new copy)"
                )
            )
        case .noSuitableMatch:
            self.init(reason: IndicatorContent(symbolName: "questionmark.circle", text: "No suitable match"))
        case .refused(let refusal):
            self.init(reason: IndicatorContent(symbolName: "nosign", text: Self.reason(for: refusal)))
        case .cancelled:
            self.init(reason: IndicatorContent(symbolName: "xmark.circle", text: "Cancelled"))
        case .failed(let failure):
            self.init(reason: IndicatorContent(symbolName: "exclamationmark.triangle", text: Self.reason(for: failure)))
        }
    }

    private init(reason: IndicatorContent) {
        self.init(content: reason, displayDuration: Self.reasonDuration)
    }

    private init(content: IndicatorContent, displayDuration: Duration) {
        self.content = content
        self.displayDuration = displayDuration
    }

    private static func reason(for refusal: PreCheckRefusal) -> String {
        switch refusal {
        case .noActiveItem: "Nothing copied yet"
        case .noEditableTarget: "No text field focused"
        case .secureField: "Secure field — not supported"
        case .suspectedSecret: "Suspected secret — blocked"
        }
    }

    private static func reason(for failure: PasteAttemptFailure) -> String {
        switch failure {
        case .timedOut: "Jev took longer than 5 s"
        case .decisionUnavailable: "Jev unavailable"
        case .invalidResult: "Jev's answer was not an exact excerpt"
        case .targetChanged: "Target changed — nothing pasted"
        }
    }
}
