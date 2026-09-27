import SmartPasteCore
import Testing

@MainActor
struct PasteAttemptStartTests {
    static let passwordField = BoundTarget(
        identity: TargetIdentity(processIdentifier: 42, elementToken: 9),
        context: TargetContext(fieldLabel: "Password"),
        isSecureField: true
    )

    @Test func hotkeyAsksJevStep1WithThePinnedItemAndTargetContext() {
        let harness = PasteAttemptHarness()

        harness.hotkey.press()

        let request = harness.jev.requests.first
        #expect(request?.sourceDocument == PasteAttemptHarness.sourceText)
        #expect(request?.targetContext == TargetContext(fieldLabel: "Email"))
        #expect(request?.questions.map(\.id) == ["narrow_0"])
        #expect(request?.questions.first?.options.first?.id == "everything")
    }

    @Test func repeatedHotkeyWhileInFlightIsIgnoredWithOneJevCall() {
        let harness = PasteAttemptHarness()

        harness.hotkey.press()
        harness.hotkey.press()

        #expect(harness.jev.requests.count == 1)
    }

    @Test(arguments: [
        PreCheckRefusal.noActiveItem, .noEditableTarget, .secureField, .suspectedSecret,
    ])
    func eachPreCheckRefusesWithoutJevCallOrPasteboardWrite(refusal: PreCheckRefusal) {
        let harness =
            switch refusal {
            case .noActiveItem: PasteAttemptHarness(copySource: false)
            case .noEditableTarget: PasteAttemptHarness(focusedTarget: nil)
            case .targetNotReady: preconditionFailure("not a Pre-check: the Wake Wait's limit, see WakeWaitTests")
            case .secureField: PasteAttemptHarness(focusedTarget: Self.passwordField)
            case .suspectedSecret: PasteAttemptHarness(sourceText: StubPreCheck.secretPrefix + "4f9a1c")
            case .noProviderKey: preconditionFailure("not a Pre-check: the Jev Provider, see JevProviderAccessTests")
            }

        harness.hotkey.press()

        #expect(harness.presenter.outcomes == [.refused(refusal)])
        #expect(harness.jev.requests.isEmpty)
        #expect(harness.log.steps.isEmpty)
    }
}
