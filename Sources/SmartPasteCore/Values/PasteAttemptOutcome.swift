/// Why a Pre-check refused a Paste Attempt before anything left the machine.
public enum PreCheckRefusal: Equatable, Sendable {
    /// Nothing has been copied yet, so there is no Active Item.
    case noActiveItem
    /// The focus is readable and no editable element is focused.
    case noEditableTarget
    /// The named app's focus was still unreadable when the Wake Wait's limit passed.
    case targetNotReady(applicationName: String)
    /// The Target is a secure field; not supported.
    case secureField
    /// The Active Item is concealed or looks like a secret.
    case suspectedSecret
}

/// Why a Paste Attempt failed after it passed the Pre-checks. Nothing was inserted.
public enum PasteAttemptFailure: Equatable, Sendable {
    /// The 5 s clock ran out, including any rate-limit back-off.
    case timedOut
    /// Jev could not be reached or answered with an error.
    case decisionUnavailable
    /// Jev refused a request's size: the copy is too long for one call. Ordinary ⌘V still pastes it whole.
    case tooLongForSmartPaste
    /// Jev's pick, or the Candidate Chooser's, was not an offered, verbatim excerpt of the Active Item.
    case invalidResult
    /// The Bound Target was no longer focused at delivery.
    case targetChanged
}

/// The visible outcome that ends a Paste Attempt.
public enum PasteAttemptOutcome: Equatable, Sendable {
    /// The Paste Result was inserted and the original clipboard restored.
    case inserted
    /// The Paste Result was inserted, but a copy made during the Restore Window replaced the original clipboard.
    case insertedWithoutRestore
    case noSuitableMatch
    case refused(PreCheckRefusal)
    case cancelled
    case failed(PasteAttemptFailure)
}
