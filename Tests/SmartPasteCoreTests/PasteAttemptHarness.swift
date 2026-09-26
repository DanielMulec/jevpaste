import SmartPasteCore

/// A Paste Attempt coordinator wired to in-memory fakes and the real Narrowing policy, with Ada's contact card copied
/// as the Active Item and an Email field focused.
@MainActor
final class PasteAttemptHarness {
    static let sourceText = "Name: Ada Lovelace\nEmail: ada@example.com\nBackup: ada@work.example"
    static let emailField = BoundTarget(
        identity: TargetIdentity(processIdentifier: 42, elementToken: 7),
        context: TargetContext(fieldLabel: "Email"),
        isSecureField: false
    )

    let clock = ManualClock()
    let log: DeliveryLog
    let hotkey = FakeHotkey()
    let clipboard: FakeClipboard
    let targetResolver: FakeTargetResolver
    let inserter: FakeInserter
    let jev = FakeDecisionService()
    let history = FakeHistoryRepository()
    let presenter: FakePresenter
    let chooser = FakeChooser()
    let capture: CopyCapture
    // periphery:ignore - held so the hotkey reaches a live coordinator; tests drive it only through the fakes.
    let coordinator: PasteAttemptCoordinator

    init(
        focusedTarget: BoundTarget? = PasteAttemptHarness.emailField,
        unreadableReads: Int = 0,
        screeningTakes: Duration = .zero,
        copySource: Bool = true,
        sourceText: String = PasteAttemptHarness.sourceText
    ) {
        log = DeliveryLog(clock: clock)
        clipboard = FakeClipboard(log: log, initialText: "")
        targetResolver = FakeTargetResolver(focusedTarget: focusedTarget, unreadableReads: unreadableReads)
        inserter = FakeInserter(log: log)
        presenter = FakePresenter(clock: clock)
        chooser.onPresent = { [presenter] in presenter.hideWhileChoosing() }
        capture = CopyCapture(clipboard: clipboard, history: history)
        let ports = PasteAttemptPorts(
            hotkey: hotkey, clipboard: clipboard, targetResolver: targetResolver, inserter: inserter,
            decisionService: jev, clock: clock, presenter: presenter, chooser: chooser
        )
        let rules = PasteAttemptRules(
            narrowingPolicy: .r2b,
            preCheck: StubPreCheck(slowness: screeningTakes == .zero ? nil : (clock, screeningTakes))
        )
        coordinator = PasteAttemptCoordinator(ports: ports, rules: rules, capture: capture)
        if copySource {
            clipboard.simulateForeignCopy(sourceText)
        }
    }

    /// Presses ⌘⇧V and lets Jev narrow to `text` right away: picks it at step 1, keeps it at step 2.
    func pasteChoosing(_ text: String) {
        hotkey.press()
        jev.narrow(to: text)
    }
}
