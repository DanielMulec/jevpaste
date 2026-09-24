import AppKit

/// The history panel's footer: key hints on the left and "Clear History…" on the right; while clear-all waits
/// for confirmation, a question with Cancel and a red Clear button takes its place.
@MainActor
final class HistoryPanelFooter: NSObject {
    let view = NSView()
    var onClearAllRequested: (@MainActor () -> Void)?
    var onClearAllConfirmed: (@MainActor () -> Void)?
    var onClearAllCancelled: (@MainActor () -> Void)?

    private let hints = NSStackView()
    private let clearButton = NSButton(title: "Clear History…", target: nil, action: nil)
    private let question = NSTextField(labelWithString: "")
    private let cancelButton = NSButton(title: "Cancel", target: nil, action: nil)
    private let confirmButton = NSButton(title: "Clear History", target: nil, action: nil)
    private lazy var normal = Self.row([hints, NSView(), clearButton])
    private lazy var confirmation = Self.row([question, NSView(), cancelButton, confirmButton])

    override init() {
        super.init()
        for (key, meaning) in [("↩", "Make Active"), ("⌘⌫", "Delete"), ("esc", "Close")] {
            hints.addArrangedSubview(Self.keyCap(key))
            hints.addArrangedSubview(Self.hint(meaning))
            hints.setCustomSpacing(12, after: hints.arrangedSubviews[hints.arrangedSubviews.count - 1])
        }
        hints.spacing = 4
        clearButton.bezelStyle = .accessoryBarAction
        clearButton.controlSize = .small
        clearButton.contentTintColor = .secondaryLabelColor
        clearButton.target = self
        clearButton.action = #selector(clearClicked)
        question.font = .systemFont(ofSize: NSFont.smallSystemFontSize, weight: .medium)
        for button in [cancelButton, confirmButton] {
            button.bezelStyle = .push
            button.controlSize = .small
            button.target = self
        }
        cancelButton.action = #selector(cancelClicked)
        confirmButton.action = #selector(confirmClicked)
        confirmButton.hasDestructiveAction = true
        confirmButton.bezelColor = .systemRed
        view.addFillingSubview(normal)
        view.addFillingSubview(confirmation)
        showNormal()
    }

    func askToConfirmClearAll(itemCount: Int) {
        question.stringValue =
            itemCount == 1 ? "Delete 1 item from history?" : "Delete all \(itemCount) items from history?"
        normal.isHidden = true
        confirmation.isHidden = false
    }

    func showNormal() {
        normal.isHidden = false
        confirmation.isHidden = true
    }

    @objc private func clearClicked() {
        onClearAllRequested?()
    }

    @objc private func cancelClicked() {
        onClearAllCancelled?()
    }

    @objc private func confirmClicked() {
        onClearAllConfirmed?()
    }

    private static func row(_ views: [NSView]) -> NSStackView {
        let stack = NSStackView(views: views)
        stack.orientation = .horizontal
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 6, left: 14, bottom: 8, right: 10)
        return stack
    }

    private static func hint(_ text: String) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        field.textColor = .secondaryLabelColor
        return field
    }

    /// A key name in a small rounded capsule, as macOS draws shortcuts in its help and onboarding.
    private static func keyCap(_ key: String) -> NSView {
        let label = hint(key)
        label.font = .systemFont(ofSize: NSFont.smallSystemFontSize - 1, weight: .medium)
        let cap = NSView()
        cap.wantsLayer = true
        cap.layer?.cornerRadius = 4
        cap.layer?.borderWidth = 1
        cap.layer?.borderColor = NSColor.separatorColor.cgColor
        label.translatesAutoresizingMaskIntoConstraints = false
        cap.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: cap.leadingAnchor, constant: 4),
            label.trailingAnchor.constraint(equalTo: cap.trailingAnchor, constant: -4),
            label.topAnchor.constraint(equalTo: cap.topAnchor, constant: 1),
            label.bottomAnchor.constraint(equalTo: cap.bottomAnchor, constant: -1),
        ])
        return cap
    }
}
