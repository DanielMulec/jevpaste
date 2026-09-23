import SmartPasteCore
import Testing

/// The Pre-checks' refusals, in order: a secure Target first, then a concealed Active Item, then a suspected
/// secret in the Active Item's text.
struct LocalPreChecksTests {
    static let ordinaryText = "maren.holtby@example.org"
    static let secretText = "Maren's token: ghp_JEVPASTE0000000000000000000000000000"

    private let preChecks = LocalPreChecks()

    private static func target(isSecureField: Bool = false, surroundingText: String = "") -> BoundTarget {
        BoundTarget(
            identity: TargetIdentity(processIdentifier: 7, elementToken: 1),
            context: TargetContext(fieldLabel: "Email address", surroundingText: surroundingText),
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
