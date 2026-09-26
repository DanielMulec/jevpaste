import AppKit
import JevGateway
import MacInterop
import SmartPasteCore
import os

/// The composition root: wires the real adapters and Core's rules into one Paste Attempt coordinator, so ⌘⇧V
/// performs a Smart Paste of the Active Item (the newest copy, or the text on the clipboard at launch). Copies
/// persist in Clipboard History; the history panel makes an older one Active (Rejev-paste).
@MainActor
final class SmartPasteApplication {
    private static let log = Logger(subsystem: "jevpaste", category: "Launch")

    // periphery:ignore - held for the app's lifetime (it holds the Copy Capture too); the hotkey drives it.
    private let coordinator: PasteAttemptCoordinator
    /// "Open at Login" for the status-item menu; its notices share the indicator.
    let loginItem: LoginItemToggle
    /// "Clipboard History…" in the status-item menu opens it.
    let historyPanel: HistoryPanelController

    init(statusItem: NSStatusItem, options: LaunchOptions) {
        Self.log.notice("launch apiKeyPresent=\(GatewayCredentials.standard.hasAPIKey, privacy: .public)")
        let clock = RunLoopPasteAttemptClock()
        let statusItemFrame: @MainActor () -> NSRect? = { [weak statusItem] in
            guard let button = statusItem?.button, let window = button.window else { return nil }
            return window.convertToScreen(button.convert(button.bounds, to: nil))
        }
        let panel = IndicatorPanel(anchorFrame: statusItemFrame)
        let notices = IndicatorNoticeSurface(wrapping: panel, clock: clock)
        let activator = WorkspaceApplicationActivator()
        let focusReturn = TargetAppFocusReturn(activator: activator, clock: clock)
        let presenter = IndicatorPresenter(surface: notices, clock: clock, focusReturn: focusReturn)
        let clipboard = SystemClipboard()
        let history = ClipboardHistoryOpening.open(notices: notices)
        let capture = CopyCapture(
            clipboard: clipboard,
            history: history,
            contentsAtLaunch: { clipboard.currentItem() }
        )
        historyPanel = HistoryPanelController(
            surface: HistoryPanel(anchorFrame: statusItemFrame), history: history, capture: capture,
            focusReturn: focusReturn, activator: activator, notices: notices
        )
        // After the history notice, so a missing grant — the more urgent one — is what shows at launch.
        loginItem = LoginItemToggle(service: MainAppLoginItemService(), notices: notices)
        let grantCheck = AccessibilityGrantCheck(trust: ProcessAccessibilityTrust(), notices: notices)
        grantCheck.checkAtLaunch()
        let keyboardHotkey = GlobalHotkey { [weak notices] status in
            guard let notices else { return }
            HotkeyRegistrationReport.failed(status: status, notices: notices)
        }
        let hotkey = AcceptanceTrigger.hotkey(wrapping: keyboardHotkey, options: options, trigger: SignalPressTrigger())
        coordinator = PasteAttemptCoordinator(
            ports: PasteAttemptPorts(
                hotkey: GrantCheckingHotkey(wrapping: hotkey, check: grantCheck),
                clipboard: clipboard,
                targetResolver: AccessibilityTargetResolver(),
                inserter: PasteKeystrokeInserter(),
                decisionService: JevGatewayDecisionService(),
                clock: clock,
                presenter: presenter,
                chooser: PanelCandidateChooser(
                    surface: ChooserPanel(anchorFrame: statusItemFrame),
                    focusReturn: focusReturn,
                    indicator: presenter
                )
            ),
            rules: PasteAttemptRules(narrowingPolicy: .r2b, preCheck: LocalPreChecks()),
            capture: capture
        )
    }
}
