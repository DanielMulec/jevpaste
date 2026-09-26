import AppKit
import SmartPasteCore

/// One provider's key in Settings › Jev Provider: a secure field (the eye button swaps in a plain field holding the
/// same text), Test, and the result right of it. Every edit goes to `ProviderKeySettings`, which saves it.
@MainActor
final class ProviderKeyRow: NSObject, NSTextFieldDelegate {
    private static let fieldWidth = 300.0

    let view: NSStackView
    private let provider: JevProvider
    private let settings: ProviderKeySettings
    private let secureField = NSSecureTextField()
    private let plainField = NSTextField()
    private let eyeButton = NSButton()
    private let testButton = NSButton(title: "Test", target: nil, action: nil)
    private let resultField = NSTextField(wrappingLabelWithString: "")
    private var isShown = false

    init(provider: JevProvider, settings: ProviderKeySettings, isEnabled: Bool) {
        self.provider = provider
        self.settings = settings
        let fields = NSStackView(views: [secureField, plainField])
        fields.spacing = 0
        view = NSStackView(views: [fields, eyeButton, testButton, resultField])
        view.spacing = 6
        super.init()
        for field in [secureField, plainField] {
            field.placeholderString = "\(provider.displayName) API key"
            field.stringValue = settings.savedKey(of: provider)
            field.delegate = self
            field.isEnabled = isEnabled
            field.translatesAutoresizingMaskIntoConstraints = false
            field.widthAnchor.constraint(equalToConstant: Self.fieldWidth).isActive = true
        }
        plainField.isHidden = true
        eyeButton.bezelStyle = .accessoryBarAction
        eyeButton.isBordered = false
        eyeButton.toolTip = "Show key"
        eyeButton.target = self
        eyeButton.action = #selector(toggleShown)
        eyeButton.isEnabled = isEnabled
        testButton.target = self
        testButton.action = #selector(runTest)
        testButton.isEnabled = isEnabled
        resultField.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        resultField.preferredMaxLayoutWidth = 180
        refresh()
    }

    /// Puts the caret into the key field (from the missing-key refusal).
    func focus() {
        let field = isShown ? plainField : secureField
        field.window?.makeFirstResponder(field)
    }

    func refresh() {
        eyeButton.image = NSImage(
            systemSymbolName: isShown ? "eye.slash" : "eye", accessibilityDescription: isShown ? "Hide key" : "Show key"
        )
        let result = settings.result(for: provider)
        resultField.stringValue = result.text(for: provider)
        resultField.textColor =
            switch result {
            case .works: .systemGreen
            case .failed, .notSaved: .systemRed
            case .missingKey: .systemOrange
            case .none, .testing: .secondaryLabelColor
            }
    }

    func controlTextDidChange(_ notification: Notification) {
        guard let edited = notification.object as? NSTextField else { return }
        (edited === secureField ? plainField : secureField).stringValue = edited.stringValue
        settings.keyEdited(edited.stringValue, for: provider)
        refresh()
    }

    @objc private func toggleShown() {
        isShown.toggle()
        secureField.isHidden = isShown
        plainField.isHidden = !isShown
        refresh()
        focus()
    }

    @objc private func runTest() {
        settings.test(provider)
        refresh()
    }
}
