import AppKit
import ApplicationServices
import JevGateway
import MacInterop
import SmartPasteCore
import os

/// The composition root: wires the real adapters and the tracer bullet's interim ones into one Paste Attempt
/// coordinator, so ⌘⇧V performs a Smart Paste of the Active Item (the newest copy, or the text on the clipboard
/// at launch). Copies persist in Clipboard History.
@MainActor
final class SmartPasteApplication {
    private static let log = Logger(subsystem: "jevpaste", category: "Launch")

    // periphery:ignore - held for the app's lifetime (it holds the Copy Capture too); the hotkey drives it.
    private let coordinator: PasteAttemptCoordinator

    init(statusItem: NSStatusItem) {
        Self.log.notice(
            """
            launch accessibilityTrusted=\(AXIsProcessTrusted(), privacy: .public) \
            apiKeyPresent=\(GatewayCredentials.standard.hasAPIKey, privacy: .public)
            """
        )
        let clock = RunLoopPasteAttemptClock()
        let statusItemFrame: @MainActor () -> NSRect? = { [weak statusItem] in
            guard let button = statusItem?.button, let window = button.window else { return nil }
            return window.convertToScreen(button.convert(button.bounds, to: nil))
        }
        let panel = IndicatorPanel(anchorFrame: statusItemFrame)
        let notices = HistoryNoticeSurface(wrapping: panel, clock: clock)
        let presenter = IndicatorPresenter(surface: notices, clock: clock)
        let clipboard = SystemClipboard()
        let capture = CopyCapture(
            clipboard: clipboard,
            history: ClipboardHistoryOpening.open(notices: notices),
            contentsAtLaunch: { clipboard.currentItem() }
        )
        coordinator = PasteAttemptCoordinator(
            ports: PasteAttemptPorts(
                hotkey: GlobalHotkey(),
                clipboard: clipboard,
                targetResolver: AccessibilityTargetResolver(),
                inserter: PasteKeystrokeInserter(),
                decisionService: JevGatewayDecisionService(),
                clock: clock,
                presenter: presenter,
                chooser: PanelCandidateChooser(
                    surface: ChooserPanel(anchorFrame: statusItemFrame),
                    focusReturn: TargetAppFocusReturn(activator: WorkspaceApplicationActivator(), clock: clock),
                    indicator: presenter
                )
            ),
            rules: PasteAttemptRules(
                candidateExtraction: StructuralCandidateExtraction(),
                preCheck: SecureTargetAndConcealedItemPreCheck()
            ),
            capture: capture
        )
    }
}
