import SmartPasteCore
import Testing

/// The Pre-checks' refusals, in order: a secure Target first, then a concealed Active Item, then a suspected
/// secret in the Active Item's text.
struct LocalPreChecksTests {
    static let ordinaryText = "maren.holtby@example.org"
    static let secretText = "Maren's token: ghp_JEVPASTE0000000000000000000000000000"

    private let preChecks = LocalPreChecks()

    private static func target(isSecureField: Bool) -> BoundTarget {
        BoundTarget(
            identity: TargetIdentity(processIdentifier: 7, elementToken: 1),
            context: TargetContext(fieldLabel: "Email address"),
            isSecureField: isSecureField
        )
    }

    @Test(arguments: [
        (isSecureField: false, isConcealed: false, text: ordinaryText, expected: nil),
        (isSecureField: false, isConcealed: true, text: ordinaryText, expected: PreCheckRefusal.suspectedSecret),
        (isSecureField: false, isConcealed: false, text: secretText, expected: .suspectedSecret),
        (isSecureField: true, isConcealed: false, text: ordinaryText, expected: .secureField),
        (isSecureField: true, isConcealed: true, text: secretText, expected: .secureField),
    ])
    func refusesSecureTargetsFirstThenConcealedOrSuspectedSecretItems(
        isSecureField: Bool, isConcealed: Bool, text: String, expected: PreCheckRefusal?
    ) {
        let item = ClipboardItem(text: text, isConcealed: isConcealed)

        #expect(preChecks.refusal(for: item, in: Self.target(isSecureField: isSecureField)) == expected)
    }
}

/// Secrets in the Target Context: the surrounding-text window is dropped before it is sent, the rest stays, and
/// the attempt carries a visible note. Not a refusal.
struct TargetContextScreeningTests {
    private let preChecks = LocalPreChecks()

    private static func context(surroundingText: String) -> TargetContext {
        TargetContext(
            fieldLabel: "Message", placeholder: "Write a reply", sectionHeading: "Deploy chat",
            siblingFieldLabels: ["Attach"], surroundingText: surroundingText
        )
    }

    private static func target(surroundingText: String) -> BoundTarget {
        BoundTarget(
            identity: TargetIdentity(processIdentifier: 7, elementToken: 1),
            context: context(surroundingText: surroundingText), isSecureField: false
        )
    }

    @Test func surroundingTextWithASuspectedSecretIsWithheldAndNoted() {
        let window = "ops: the prod DB is postgres://deploy:hunter2@db.example.org/app\nyou: which one?"

        let screened = preChecks.screenedContext(of: Self.target(surroundingText: window))

        #expect(screened.context == Self.context(surroundingText: ""))
        #expect(screened.note == .surroundingTextWithheld)
    }

    @Test func ordinarySurroundingTextIsSentUnchanged() {
        let window = "ops: which email should I use for the invoice?\nyou: "

        let screened = preChecks.screenedContext(of: Self.target(surroundingText: window))

        #expect(screened.context == Self.context(surroundingText: window))
        #expect(screened.note == nil)
    }
}

/// The Opaque Token refuses only the Active Item (Daniel, review of "Refuse any copied API key at ⌘⇧V, whatever its
/// vendor"): a Target Context that is one bare token — a commit hash in a terminal, a ticket id as a window title —
/// is sent unchanged, because withholding it would cost Jev context and protect nothing that was copied.
struct OpaqueTokenItemOnlyTests {
    private static let bareToken = "JEVPASTEk3y0123456789abcdef"
    private let preChecks = LocalPreChecks()

    private static func target(surroundingText: String = "", windowTitle: String? = nil) -> BoundTarget {
        BoundTarget(
            identity: TargetIdentity(processIdentifier: 7, elementToken: 1),
            context: TargetContext(fieldLabel: "Message", surroundingText: surroundingText, windowTitle: windowTitle),
            isSecureField: false
        )
    }

    @Test func anActiveItemThatIsOneBareTokenIsRefused() {
        let item = ClipboardItem(text: Self.bareToken, isConcealed: false)

        #expect(preChecks.refusal(for: item, in: Self.target()) == .suspectedSecret)
    }

    @Test func surroundingTextThatIsOneBareTokenIsSentUnchanged() {
        let target = Self.target(surroundingText: Self.bareToken)

        let screened = preChecks.screenedContext(of: target)

        #expect(screened.context == target.context)
        #expect(screened.note == nil)
    }

    @Test func aWindowTitleThatIsOneBareTokenIsSentUnchanged() {
        let target = Self.target(windowTitle: Self.bareToken)

        let screened = preChecks.screenedContext(of: target)

        #expect(screened.context == target.context)
        #expect(screened.note == nil)
    }
}
