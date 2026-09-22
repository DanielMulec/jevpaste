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

    init(source: Source) {
        self.source = source
    }

    func resolveFocusedTarget() -> BoundTarget? {
        guard let focused = source.focusedElement(), focused.node.isEditable else { return nil }
        lastMintedToken += 1
        boundElement = (lastMintedToken, focused.node)
        let isSecureField = focused.node.isSecureTextField || source.isSecureEventInputEnabled
        return BoundTarget(
            identity: TargetIdentity(processIdentifier: focused.processIdentifier, elementToken: lastMintedToken),
            context: isSecureField ? TargetContext() : contextReader.context(of: focused),
            isSecureField: isSecureField
        )
    }

    func isStillFocused(_ target: TargetIdentity) -> Bool {
        guard let boundElement, boundElement.token == target.elementToken,
            let focused = source.focusedElement()
        else { return false }
        return focused.processIdentifier == target.processIdentifier
            && focused.node.isSameElement(as: boundElement.node)
    }
}
