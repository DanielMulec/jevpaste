import SmartPasteCore

/// The `TargetResolver` adapter: finds the focused editable Target through Accessibility and re-verifies that
/// the same element in the same process still has focus right before insertion.
@MainActor
public final class AccessibilityTargetResolver: TargetResolver {
    private let resolver = FocusedTargetResolver(source: AXFocusSource())

    public init() {}

    public func resolveFocusedTarget() -> BoundTarget? {
        resolver.resolveFocusedTarget()
    }

    public func isStillFocused(_ target: TargetIdentity) -> Bool {
        resolver.isStillFocused(target)
    }
}
