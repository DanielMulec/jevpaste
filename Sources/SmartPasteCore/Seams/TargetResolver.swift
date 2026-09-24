/// Identifies the focused editable Target and its Target Context, and re-verifies the Bound Target
/// immediately before insertion.
///
/// The real adapter lives in `MacInterop` (Accessibility); tests supply an in-memory fake.
@MainActor
public protocol TargetResolver {
    /// The focused editable element, or why there is none.
    func resolveFocusedTarget() -> TargetResolution
    /// Whether the same process and the same element are still focused.
    func isStillFocused(_ target: TargetIdentity) -> Bool
}

/// What the `TargetResolver` found at ⌘⇧V.
public enum TargetResolution: Equatable, Sendable {
    /// An editable element is focused; it becomes the Bound Target.
    case resolved(BoundTarget)
    /// Nothing editable is focused.
    case noEditableTarget
    /// The frontmost app's focus is unreadable until its Accessibility wakes, which was just requested; ⌘⇧V again
    /// in a moment finds the Target.
    case waking(applicationName: String)
}
