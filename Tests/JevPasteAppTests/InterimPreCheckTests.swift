import SmartPasteCore
import Testing

@testable import JevPasteApp

struct InterimPreCheckTests {
    private let preCheck = SecureTargetAndConcealedItemPreCheck()

    @Test(arguments: [
        (isSecureField: false, isConcealed: false, expected: nil),
        (isSecureField: false, isConcealed: true, expected: PreCheckRefusal.suspectedSecret),
        (isSecureField: true, isConcealed: false, expected: PreCheckRefusal.secureField),
        (isSecureField: true, isConcealed: true, expected: PreCheckRefusal.secureField),
    ])
    func refusesSecureTargetsFirstThenConcealedItems(
        isSecureField: Bool, isConcealed: Bool, expected: PreCheckRefusal?
    ) {
        let item = ClipboardItem(text: "maren.holtby@example.org", isConcealed: isConcealed)
        let target = BoundTarget(
            identity: TargetIdentity(processIdentifier: 7, elementToken: 1),
            context: TargetContext(fieldLabel: "Email address"),
            isSecureField: isSecureField
        )

        #expect(preCheck.refusal(for: item, in: target) == expected)
    }
}
