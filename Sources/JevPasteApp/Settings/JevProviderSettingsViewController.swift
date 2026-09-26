import AppKit
import JevGateway
import SmartPasteCore

/// Settings › Jev Provider: the provider picker (only built providers can be chosen; the choice applies from the next
/// Paste Attempt) and one key row per provider.
@MainActor
final class JevProviderSettingsViewController: NSViewController {
    private let choice: JevProviderChoice
    private let settings: ProviderKeySettings
    private var radios: [JevProvider: NSButton] = [:]
    private var rows: [JevProvider: ProviderKeyRow] = [:]

    init(choice: JevProviderChoice, settings: ProviderKeySettings) {
        self.choice = choice
        self.settings = settings
        super.init(nibName: nil, bundle: nil)
        settings.onResultChange = { [weak self] provider in self?.rows[provider]?.refresh() }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func loadView() {
        var keyViews: [NSView] = []
        for provider in JevProvider.allCases {
            let isBuilt = JevGatewayAccess.builtProviders.contains(provider)
            let title = provider == .standard ? provider.displayName + " (default)" : provider.displayName
            let radio = NSButton(radioButtonWithTitle: title, target: self, action: #selector(radioChosen))
            radio.isEnabled = isBuilt
            radios[provider] = radio
            let row = ProviderKeyRow(provider: provider, settings: settings, isEnabled: isBuilt)
            rows[provider] = row
            keyViews += [SettingsLayout.heading(provider.displayName, size: 11), row.view]
        }
        let radioColumn = SettingsLayout.column(JevProvider.allCases.compactMap { radios[$0] }, spacing: 6, inset: 0)
        let hint = SettingsLayout.note(
            "Every Smart Paste goes through the chosen Jev Provider. Without its key, ⌘⇧V refuses — it never switches "
                + "to the other provider. A change applies from the next ⌘⇧V."
        )
        view = SettingsLayout.column(
            [SettingsLayout.heading("Jev Provider"), radioColumn, hint, SettingsLayout.heading("API keys")] + keyViews
        )
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        for (provider, radio) in radios {
            radio.state = provider == choice.provider ? .on : .off
        }
        for row in rows.values {
            row.refresh()
        }
    }

    /// Opened from "No key for <provider> — open Settings": the note at the field, and the caret in it.
    func focusKey(of provider: JevProvider) {
        settings.openedForMissingKey(of: provider)
        rows[provider]?.refresh()
        rows[provider]?.focus()
    }

    @objc private func radioChosen(_ sender: NSButton) {
        guard let provider = radios.first(where: { $0.value === sender })?.key else { return }
        choice.choose(provider)
    }
}
