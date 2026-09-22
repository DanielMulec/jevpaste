/// How the shell learns what to show for a Paste Attempt: the processing indicator, the retrying state and the
/// visible outcome. All of it is non-focus-stealing.
///
/// The real adapter lives in the app shell; tests supply an in-memory fake.
@MainActor
public protocol PasteOutcomePresenter {
    /// Shows the processing indicator. `onCancel` is called when Esc is pressed on it.
    func showProcessing(onCancel: @escaping @MainActor () -> Void)
    /// Shows that Jev asked us to wait and the attempt will retry.
    func showRetrying()
    /// Shows the outcome (✓, reason or note) and hides the processing indicator.
    func showOutcome(_ outcome: PasteAttemptOutcome)
}
