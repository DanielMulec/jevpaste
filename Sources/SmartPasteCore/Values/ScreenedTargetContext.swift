/// A visible note that accompanies a Paste Attempt's outcome without changing it.
public enum PasteAttemptNote: Equatable, Sendable {
    /// The surrounding text around the Target held a suspected secret, so it was not sent to Jev; the field
    /// label, placeholder, section heading and sibling labels were.
    case surroundingTextWithheld
}

/// The Target Context as it may leave the machine, and the note the attempt carries because of it.
public struct ScreenedTargetContext: Equatable, Sendable {
    public let context: TargetContext
    public let note: PasteAttemptNote?

    public init(context: TargetContext, note: PasteAttemptNote?) {
        self.context = context
        self.note = note
    }
}
