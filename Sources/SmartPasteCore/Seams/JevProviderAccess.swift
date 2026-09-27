/// Reads the Jev Provider chosen in Settings and its key, once per Paste Attempt at ⌘⇧V. The real adapter lives in
/// `JevGateway`; tests supply an in-memory fake.
@MainActor
public protocol JevProviderAccess {
    /// The chosen provider's decision service for one Paste Attempt — it serves every request of that attempt, so a
    /// change in Settings applies from the next one — or, when that provider has no key, which provider it is.
    func openForPasteAttempt() -> JevProviderOpening
}

/// How opening the chosen Jev Provider for a Paste Attempt went.
public enum JevProviderOpening {
    case ready(any DecisionService)
    /// The chosen provider has no key; the attempt is refused and never switches to another provider.
    case noKey(JevProvider)
}
