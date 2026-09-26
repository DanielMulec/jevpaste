import AppKit

/// Settings › General: the Open at Login switch, read from the system each time the tab shows.
@MainActor
final class GeneralSettingsViewController: NSViewController {
    private let loginItem: LoginItemToggle
    private let loginSwitch = NSSwitch()
    private let approvalNote = SettingsLayout.note("Approve JevPaste in System Settings › General › Login Items.")

    init(loginItem: LoginItemToggle) {
        self.loginItem = loginItem
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func loadView() {
        loginSwitch.target = self
        loginSwitch.action = #selector(switchToggled)
        let row = NSStackView(views: [NSTextField(labelWithString: "Open at Login"), NSView(), loginSwitch])
        row.translatesAutoresizingMaskIntoConstraints = false
        row.widthAnchor.constraint(equalToConstant: SettingsLayout.contentWidth).isActive = true
        view = SettingsLayout.column([row, approvalNote])
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        refresh()
    }

    @objc private func switchToggled() {
        loginItem.toggle()
        refresh()
    }

    private func refresh() {
        let state = loginItem.switchState
        loginSwitch.state = state == .disabled ? .off : .on
        approvalNote.isHidden = state != .awaitingApproval
    }
}
