import SmartPasteCore

/// The rules of the `TargetResolver` over any `FocusSource`: which focus is an editable Target, whether it is
/// secure, its Target Context, and the element token that lets the Bound Target be re-verified.
@MainActor
final class FocusedTargetResolver<Source: FocusSource> {
    private let source: Source
    private let contextReader = TargetContextReader<Source.Node>()
    private var lastMintedToken: UInt64 = 0
    /// Only the most recently bound element can be re-verified: one Paste Attempt exists at a time.
    private var boundElement: (token: UInt64, node: Source.Node)?
    /// Processes whose Accessibility switch was checked (and turned on if it was off): each is asked at most once.
    private var checkedProcesses: Set<Int32> = []

    init(source: Source) {
        self.source = source
    }

    func resolveFocusedTarget() -> TargetResolution {
        guard let focused = source.focusedElement() else { return resolutionWhileFocusIsUnreadable() }
        guard focused.node.isEditable else { return .noEditableTarget }
        lastMintedToken += 1
        boundElement = (lastMintedToken, focused.node)
        let isSecureField = focused.node.isSecureTextField || source.isSecureEventInputEnabled
        return .resolved(
            BoundTarget(
                identity: TargetIdentity(processIdentifier: focused.processIdentifier, elementToken: lastMintedToken),
                context: isSecureField ? TargetContext() : contextReader.context(of: focused),
                isSecureField: isSecureField
            )
        )
    }

    func isStillFocused(_ target: TargetIdentity) -> Bool {
        guard let boundElement, boundElement.token == target.elementToken,
            let focused = source.focusedElement()
        else { return false }
        return focused.processIdentifier == target.processIdentifier
            && focused.node.isSameElement(as: boundElement.node)
    }

    /// An unreadable focus is never "no text field": Core re-reads it during the Wake Wait. Some apps (Electron) keep
    /// their tree asleep until an assistive client turns Accessibility fully on, so each app process whose switch
    /// is off is asked once to turn it on; the wake then shows up in a later read.
    private func resolutionWhileFocusIsUnreadable() -> TargetResolution {
        guard let application = source.frontmostApplication() else { return .noEditableTarget }
        let (isNew, _) = checkedProcesses.insert(application.processIdentifier)
        if isNew, !source.isAccessibilityAwake(in: application.processIdentifier) {
            source.wakeAccessibility(in: application.processIdentifier)
        }
        return .focusUnreadable(applicationName: application.name)
    }
}
