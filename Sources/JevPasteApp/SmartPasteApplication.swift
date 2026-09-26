import AppKit
import JevGateway
import MacInterop
import SmartPasteCore
import os

/// The composition root: wires the real adapters and Core's rules into one Paste Attempt coordinator, so ⌘⇧V
/// performs a Smart Paste of the Active Item (the newest copy, or the text on the clipboard at launch) through the
/// chosen Jev Provider. Copies persist in Clipboard History; History Search makes an older one Active (Rejev-paste);
/// Settings holds Open at Login, the Jev Provider and its keys, and Full History.
@MainActor
final class SmartPasteApplication {
    private static let log = Logger(subsystem: "jevpaste", category: "Launch")

    // periphery:ignore - held for the app's lifetime (it holds the Copy Capture too); the hotkey drives it.
    private let coordinator: PasteAttemptCoordinator
    /// A click on the status item toggles it.
    let historySearch: HistorySearchController

    init(statusItem: NSStatusItem, options: LaunchOptions) {
        let keys = KeychainJevKeyStore()
        JevKeyImport.runOnce(into: keys, from: .standard, remembering: .standard)
        let providerChoice = JevProviderChoice(defaults: .standard)
        Self.logLaunch(provider: providerChoice.provider, keys: keys)
        let jevAccess = JevGatewayAccess(credentials: keys, chosenProvider: { providerChoice.provider })
        let clock = RunLoopPasteAttemptClock()
        let statusItemFrame: @MainActor () -> NSRect? = { [weak statusItem] in
            guard let button = statusItem?.button, let window = button.window else { return nil }
            return window.convertToScreen(button.convert(button.bounds, to: nil))
        }
        let notices = IndicatorNoticeSurface(wrapping: IndicatorPanel(anchorFrame: statusItemFrame), clock: clock)
        let activator = WorkspaceApplicationActivator()
        let focusReturn = TargetAppFocusReturn(activator: activator, clock: clock)
        let presenter = IndicatorPresenter(surface: notices, clock: clock, focusReturn: focusReturn)
        let clipboard = SystemClipboard()
        let history = ClipboardHistoryOpening.open(notices: notices)
        let capture = CopyCapture(clipboard: clipboard, history: history, contentsAtLaunch: { clipboard.currentItem() })
        let changes = ActiveItemChanges(capture: capture)
        // After the history notice, so a missing grant — the more urgent one — is what shows at launch.
        let settings = SettingsWindowController.assemble(
            loginItem: LoginItemToggle(service: MainAppLoginItemService(), notices: notices),
            keys: keys, choice: providerChoice, jevAccess: jevAccess,
            fullHistory: FullHistoryList(history: history, capture: capture, changes: changes)
        )
        presenter.opensSettingsToKey = { settings.open(.key($0)) }
        historySearch = HistorySearchController(
            surface: HistorySearchPanel(anchorFrame: statusItemFrame), history: history, capture: capture,
            changes: changes, focusReturn: focusReturn, activator: activator, notices: notices,
            destinations: HistorySearchDestinations(
                openSettings: { section in Task { @MainActor in settings.open(section) } },
                quit: { NSApp.terminate(nil) }
            )
        )
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
                jevProvider: jevAccess,
                clock: clock,
                presenter: presenter,
                chooser: PanelCandidateChooser(
                    surface: ChooserPanel(anchorFrame: statusItemFrame), focusReturn: focusReturn, indicator: presenter
                )
            ),
            rules: PasteAttemptRules(narrowingPolicy: .r2b, preCheck: LocalPreChecks()),
            capture: capture
        )
    }

    /// `launch provider=vercelAIGateway apiKeyPresent=true` — the provider's name and a boolean, never the key.
    private static func logLaunch(provider: JevProvider, keys: any JevKeyStore) {
        let isKeyPresent = keys.apiKey(for: provider) != nil
        log.notice(
            "launch provider=\(provider.rawValue, privacy: .public) apiKeyPresent=\(isKeyPresent, privacy: .public)")
    }
}
