import SmartPasteCore

/// The rules of the `TargetResolver` over any `FocusSource`: which focus is an editable Target, whether it is
/// secure, its Target Context, and the element token that lets the Bound Target be re-verified.
@MainActor
final class FocusedTargetResolver<Source: FocusSource> {
    /// How long after a wake request an unreadable focus in that app is still reported as waking (live: the
    /// ChatGPT app's tree came up 1–3 s after the request).
    private static var wakeWindow: Duration { .seconds(5) }

    private let source: Source
    private let now: @MainActor () -> ContinuousClock.Instant
    private let contextReader = TargetContextReader<Source.Node>()
    private var lastMintedToken: UInt64 = 0
    /// Only the most recently bound element can be re-verified: one Paste Attempt exists at a time.
    private var boundElement: (token: UInt64, node: Source.Node)?
    private var lastWake: (processIdentifier: Int32, requestedAt: ContinuousClock.Instant)?

    init(source: Source, now: @escaping @MainActor () -> ContinuousClock.Instant = { ContinuousClock.now }) {
        self.source = source
        self.now = now
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

    /// Some apps (Electron) keep their tree asleep until an assistive client turns Accessibility fully on. Ask once
    /// per app process, only when its focus is unreadable and it is not already on; ⌘⇧V is the retry.
    private func resolutionWhileFocusIsUnreadable() -> TargetResolution {
        guard let application = source.frontmostApplication() else { return .noEditableTarget }
        let waking = TargetResolution.waking(applicationName: application.name)
        if isWithinWakeWindow(of: application.processIdentifier) { return waking }
        guard !source.isAccessibilityAwake(in: application.processIdentifier),
            source.wakeAccessibility(in: application.processIdentifier)
        else { return .noEditableTarget }
        lastWake = (application.processIdentifier, now())
        return waking
    }

    private func isWithinWakeWindow(of processIdentifier: Int32) -> Bool {
        guard let lastWake, lastWake.processIdentifier == processIdentifier else { return false }
        return now() - lastWake.requestedAt < Self.wakeWindow
    }
}
