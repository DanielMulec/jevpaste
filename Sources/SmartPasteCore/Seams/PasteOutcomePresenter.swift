/// How the shell learns what to show for a Paste Attempt: the processing indicator, the retrying state, the start
/// of delivery and the visible outcome. All of it is non-focus-stealing.
///
/// The real adapter lives in the app shell; tests supply an in-memory fake.
@MainActor
public protocol PasteOutcomePresenter {
    /// Shows the processing indicator. `onCancel` is called when Esc is pressed on it.
    func showProcessing(onCancel: @escaping @MainActor () -> Void)
    /// Shows that Jev asked us to wait and the attempt will retry.
    func showRetrying()
    /// Delivery started: it can no longer be cancelled and ends with an outcome within the Restore Window.
    func showDelivering()
    /// Shows the outcome (✓ or reason), with `note` when the attempt carries one, and hides the processing
    /// indicator. `path` is the Smart Paste path the attempt took, `nil` when it ended before taking one; it is for
    /// diagnostics and never changes what is shown.
    func showOutcome(_ outcome: PasteAttemptOutcome, note: PasteAttemptNote?, path: SmartPastePath?)
    /// Shows No Suitable Match with the offer to paste the whole Active Item into `target` on Enter. Calls at most
    /// one of `onAccept` (Enter) or `onDismiss` (Esc, click-away), once focus is back in the Bound Target's app.
    /// A later `showOutcome` withdraws the offer without calling either.
    func showNoSuitableMatchOffer(
        for target: BoundTarget, onAccept: @escaping @MainActor () -> Void,
        onDismiss: @escaping @MainActor () -> Void
    )
}
