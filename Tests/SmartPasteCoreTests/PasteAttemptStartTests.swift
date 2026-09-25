import SmartPasteCore
import Testing

@MainActor
struct PasteAttemptStartTests {
    static let passwordField = BoundTarget(
        identity: TargetIdentity(processIdentifier: 42, elementToken: 9),
        context: TargetContext(fieldLabel: "Password"),
        isSecureField: true
    )

    @Test func hotkeyAsksJevWithThePinnedItemTargetContextAndCandidates() {
        let harness = PasteAttemptHarness()

        harness.hotkey.press()

        let request = harness.jev.requests.first
        #expect(request?.sourceDocument == PasteAttemptHarness.sourceText)
        #expect(request?.targetContext == TargetContext(fieldLabel: "Email"))
        #expect(request?.candidates == PasteAttemptHarness.candidates)
    }

    @Test func repeatedHotkeyWhileInFlightIsIgnoredWithOneJevCall() {
        let harness = PasteAttemptHarness()

        harness.hotkey.press()
        harness.hotkey.press()

        #expect(harness.jev.requests.count == 1)
    }

    @Test(arguments: [
        PreCheckRefusal.noActiveItem, .noEditableTarget,
        .targetNotReady(applicationName: FakeTargetResolver.unreadableApplication),
        .secureField, .suspectedSecret,
    ])
    func eachPreCheckRefusesWithoutJevCallOrPasteboardWrite(refusal: PreCheckRefusal) {
        let harness =
            switch refusal {
            case .noActiveItem: PasteAttemptHarness(copySource: false)
            case .noEditableTarget: PasteAttemptHarness(focusedTarget: nil)
            case .targetNotReady: PasteAttemptHarness(unreadableReads: .max)
            case .secureField: PasteAttemptHarness(focusedTarget: Self.passwordField)
            case .suspectedSecret: PasteAttemptHarness(sourceText: StubPreCheck.secretPrefix + "4f9a1c")
            }

        harness.hotkey.press()
        harness.clock.advance(by: .seconds(3))  // the Wake Wait's limit; every other refusal comes at once

        #expect(harness.presenter.outcomes == [.refused(refusal)])
        #expect(harness.jev.requests.isEmpty)
        #expect(harness.log.steps.isEmpty)
    }
}
