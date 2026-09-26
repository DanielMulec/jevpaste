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

    /// While the Wake Wait waits for `applicationName`'s focus to become readable; cancelled like processing.
    static func waking(applicationName: String) -> IndicatorContent {
        IndicatorContent(symbolName: "ellipsis.circle", text: "Waking \(applicationName)…" + cancelHint)
    }

    /// While delivering: uninterruptible and over within the Restore Window, so it never offers a cancel.
    static let delivering = IndicatorContent(symbolName: "arrow.down.doc", text: "Pasting…")

    /// No Suitable Match, offering Enter to paste the whole Active Item.
    static let noSuitableMatchOffer = IndicatorContent(
        symbolName: "questionmark.circle", text: "No suitable match — press Enter to paste everything"
    )

    /// While waiting to retry after Jev asked us to; the click hint appears only when a click actually cancels.
    static func retrying(cancellable: Bool) -> IndicatorContent {
        IndicatorContent(symbolName: "hourglass", text: "Jev asked us to wait…" + (cancellable ? cancelHint : ""))
    }
}

/// The visible form of a Paste Attempt outcome: ✓ for a second on success, otherwise the reason for 2.5 s. A note
/// is appended to the outcome's line and keeps it up for 2.5 s, success included, so it can be read.
struct OutcomeMessage: Equatable {
    let content: IndicatorContent
    let displayDuration: Duration

    private static let successDuration = Duration.seconds(1)
    private static let reasonDuration = Duration.milliseconds(2500)

    init(_ outcome: PasteAttemptOutcome, note: PasteAttemptNote?) {
        let message = OutcomeMessage(outcome)
        guard let note else {
            self = message
            return
        }
        self.init(
            reason: IndicatorContent(
                symbolName: message.content.symbolName, text: message.content.text + " · " + Self.text(for: note)
            )
        )
    }

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

    /// The outcome's kind for diagnostic logs, unqualified and without associated values: `inserted`,
    /// `refused.noEditableTarget`, `refused.targetNotReady`, `failed.timedOut`.
    static func logName(for outcome: PasteAttemptOutcome) -> String {
        switch outcome {
        case .refused(let refusal): "refused.\(caseName(of: refusal))"
        case .failed(let failure): "failed.\(failure)"
        default: "\(outcome)"
        }
    }

    /// Fixed names, so an associated value (an app name) never reaches the log.
    private static func caseName(of refusal: PreCheckRefusal) -> String {
        switch refusal {
        case .noActiveItem: "noActiveItem"
        case .noEditableTarget: "noEditableTarget"
        case .targetNotReady: "targetNotReady"
        case .secureField: "secureField"
        case .suspectedSecret: "suspectedSecret"
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
        case .targetNotReady(let applicationName): "\(applicationName) isn't ready — press ⌘⇧V again"
        case .secureField: "Secure field — not supported"
        case .suspectedSecret: "Suspected secret — blocked"
        }
    }

    private static func text(for note: PasteAttemptNote) -> String {
        switch note {
        case .surroundingTextWithheld: "nearby text withheld (suspected secret)"
        case .windowTitleWithheld: "window title withheld (suspected secret)"
        case .surroundingTextAndWindowTitleWithheld: "nearby text and window title withheld (suspected secret)"
        }
    }

    private static func reason(for failure: PasteAttemptFailure) -> String {
        switch failure {
        case .timedOut: "Jev took longer than 5 s"
        case .decisionUnavailable: "Jev unavailable"
        case .tooLongForSmartPaste: "Too long for Smart Paste — ⌘V pastes it whole"
        case .invalidResult: "Jev's answer was not an exact excerpt"
        case .targetChanged: "Target changed — nothing pasted"
        }
    }
}
