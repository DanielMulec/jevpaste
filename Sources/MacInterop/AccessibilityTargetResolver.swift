import SmartPasteCore

/// The `TargetResolver` adapter that will find the focused editable Target through Accessibility.
///
/// Scaffold only: no Accessibility calls yet.
public struct AccessibilityTargetResolver: TargetResolver {
    public init() {}

    public func resolveFocusedTarget() -> BoundTarget? {
        nil
    }

    public func isStillFocused(_ target: TargetIdentity) -> Bool {
        false
    }
}
