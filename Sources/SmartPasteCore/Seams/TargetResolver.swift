/// Identifies the focused editable Target and its Target Context, and re-verifies the Bound Target
/// immediately before insertion.
///
/// The real adapter lives in `MacInterop` (Accessibility); tests supply an in-memory fake.
@MainActor
public protocol TargetResolver {
    /// The focused editable element, or `nil` when none is focused.
    func resolveFocusedTarget() -> BoundTarget?
    /// Whether the same process and the same element are still focused.
    func isStillFocused(_ target: TargetIdentity) -> Bool
}
