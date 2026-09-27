/// Recognises copied text that must never enter Clipboard History because it is a secret JevPaste itself holds —
/// a stored Jev Provider key. Such a copy is handled like a marked secret: it becomes the Active Item as a
/// concealed item and is not recorded. The app's adapter compares against the key store, so Core never sees a key.
@MainActor
public protocol CaptureExclusion {
    /// Whether `text`, exactly as copied, is excluded. Never logs or keeps `text`.
    func excludes(_ text: String) -> Bool
}

/// Excludes nothing: for harnesses and tools without stored secrets.
public struct NoCaptureExclusion: CaptureExclusion {
    public init() {}

    public func excludes(_ text: String) -> Bool { false }
}
