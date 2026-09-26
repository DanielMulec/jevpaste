// PROTOTYPE — menu-settings, never merged
import AppKit

/// One provider's API key: secure field, Show control, Test button, result. The three Settings layouts differ in
/// how Show looks (`ShowStyle`) and where the result goes (`ResultPlacement`).
@MainActor
final class KeyRow: NSObject, NSTextFieldDelegate {
    enum ShowStyle { case eyeButton, checkbox }
    enum ResultPlacement { case inline, below, external }

    let provider: JevProvider
    let view: NSView
    /// For `.external`: the text to show elsewhere (S3 shows it in its section header).
    var onResult: ((NSAttributedString) -> Void)?

    private let state = ProtoState.shared
    private let secure = NSSecureTextField()
    private let plain = NSTextField()
    private let result = NSTextField(wrappingLabelWithString: "")
    private let eye = NSButton()
    private let showBox = NSButton(checkboxWithTitle: "Show key", target: nil, action: nil)
    private var shown = false
    private var missingNote = false

    init(provider: JevProvider, show: ShowStyle, placement: ResultPlacement, width: Double = 300) {
        self.provider = provider
        let test = NSButton(title: "Test", target: nil, action: nil)
        for field in [secure, plain] {
            field.placeholderString = provider == .gateway ? "vck_…" : "Typesafe API key"
            field.stringValue = ProtoState.shared.keys[provider] ?? ""
            field.translatesAutoresizingMaskIntoConstraints = false
            field.widthAnchor.constraint(equalToConstant: width).isActive = true
        }
        plain.isHidden = true
        let fieldStack = NSStackView(views: [secure, plain])
        fieldStack.spacing = 0
        var line: [NSView] = [fieldStack]
        if show == .eyeButton { line.append(eye) }
        line.append(test)
        if placement == .inline { line.append(result) }
        let row = NSStackView(views: line)
        row.spacing = 6
        var column: [NSView] = [row]
        if show == .checkbox { column.append(showBox) }
        if placement == .below { column.append(result) }
        let stack = NSStackView(views: column)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        view = stack
        super.init()
        for field in [secure, plain] { field.delegate = self }
        eye.bezelStyle = .accessoryBarAction
        eye.isBordered = false
        eye.target = self
        eye.action = #selector(toggleShow)
        eye.toolTip = "Show key"
        showBox.target = self
        showBox.action = #selector(toggleShow)
        test.target = self
        test.action = #selector(runTest)
        result.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        result.preferredMaxLayoutWidth = placement == .inline ? 180 : width + 60
        result.isHidden = placement == .external
        refresh()
    }

    func focus() {
        let field = shown ? plain : secure
        field.window?.makeFirstResponder(field)
    }

    /// Opened from "No key for <provider> — open Settings": say so right at the field.
    func markMissing() {
        missingNote = true
        refresh()
    }

    func refresh() {
        eye.image = NSImage(systemSymbolName: shown ? "eye.slash" : "eye", accessibilityDescription: "Show key")
        showBox.state = shown ? .on : .off
        let text: NSAttributedString
        switch state.testResults[provider] ?? .none {
        case .none:
            text = missingNote && (state.keys[provider] ?? "").isEmpty
                ? Self.colored("⚠︎ No key for \(provider.rawValue) — paste it here.", .systemOrange) : NSAttributedString()
        case .testing: text = Self.colored("Testing…", .secondaryLabelColor)
        case .ok: text = Self.colored("✓ Works — Jev answered through \(provider.rawValue).", .systemGreen)
        case let .failed(message): text = Self.colored("✕ \(message)", .systemRed)
        }
        result.attributedStringValue = text
        onResult?(text)
    }

    static func colored(_ text: String, _ color: NSColor) -> NSAttributedString {
        NSAttributedString(string: text, attributes: [
            .foregroundColor: color, .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
        ])
    }

    func controlTextDidChange(_ notification: Notification) {
        guard let field = notification.object as? NSTextField else { return }
        (field === secure ? plain : secure).stringValue = field.stringValue
        state.keys[provider] = field.stringValue
        state.testResults[provider] = TestResult.none
        state.note("key for \(provider.rawValue) edited (\(field.stringValue.count) chars)")
    }

    @objc private func toggleShow() {
        shown.toggle()
        secure.isHidden = shown
        plain.isHidden = !shown
        state.note("Show key \(provider.rawValue): \(shown ? "on" : "off")")
        focus()
    }

    @objc private func runTest() {
        state.test(provider)
    }
}

/// The Full History list: every Clipboard Item with a delete button, the count, and a guarded Clear History.
@MainActor
final class FullHistoryList: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    let view: NSView
    private let table = NSTableView()
    private let count = NSTextField(labelWithString: "")
    private let state = ProtoState.shared

    init(height: Double) {
        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.borderType = .noBorder
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.heightAnchor.constraint(equalToConstant: height).isActive = true
        let clear = NSButton(title: "Clear History…", target: nil, action: nil)
        count.textColor = .secondaryLabelColor
        count.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        let footer = NSStackView(views: [count, NSView(), clear])
        let stack = NSStackView(views: [scroll, footer])
        stack.orientation = .vertical
        stack.spacing = 8
        for part in [scroll, footer] as [NSView] {
            part.translatesAutoresizingMaskIntoConstraints = false
            part.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        view = stack
        super.init()
        clear.target = self
        clear.action = #selector(clearHistory)
        let column = NSTableColumn(identifier: .init("item"))
        table.addTableColumn(column)
        table.headerView = nil
        table.rowHeight = 36
        table.style = .inset
        table.usesAlternatingRowBackgroundColors = true
        table.dataSource = self
        table.delegate = self
        reload()
    }

    func reload() {
        table.reloadData()
        count.stringValue = "\(state.items.count) Clipboard Items"
    }

    func numberOfRows(in tableView: NSTableView) -> Int { state.items.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let item = state.items[row]
        let title = NSTextField(labelWithString: item.firstLine)
        title.lineBreakMode = .byTruncatingTail
        title.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let detail = NSTextField(labelWithString: item.detailText)
        detail.font = .systemFont(ofSize: 11)
        detail.textColor = .secondaryLabelColor
        let texts = NSStackView(views: [title, detail])
        texts.orientation = .vertical
        texts.alignment = .leading
        texts.spacing = 1
        var views: [NSView] = [texts, NSView()]
        if item.id == state.activeID {
            views.append(NSImageView(image: RowLook.capsule("Active", tint: .controlAccentColor)))
        }
        let delete = ClosureButton(symbol: "xmark.circle.fill", tip: "Delete from Clipboard History") { [weak self] in
            self?.state.delete(item.id)
        }
        views.append(delete)
        let stack = NSStackView(views: views)
        stack.edgeInsets = NSEdgeInsets(top: 0, left: 4, bottom: 0, right: 4)
        return stack
    }

    @objc private func clearHistory() {
        let alert = NSAlert()
        alert.messageText = "Clear History?"
        alert.informativeText = "All \(state.items.count) Clipboard Items are removed from Clipboard History. "
            + "This cannot be undone."
        alert.addButton(withTitle: "Clear History").hasDestructiveAction = true
        alert.addButton(withTitle: "Cancel")
        guard let window = view.window else { return }
        alert.beginSheetModal(for: window) { [weak self] response in
            if response == .alertFirstButtonReturn { self?.state.clearHistory() }
        }
    }
}

final class ClosureButton: NSButton {
    private var run: () -> Void = {}

    convenience init(symbol: String, tip: String, run: @escaping () -> Void) {
        self.init(frame: .zero)
        self.run = run
        image = NSImage(systemSymbolName: symbol, accessibilityDescription: tip)
        isBordered = false
        imagePosition = .imageOnly
        contentTintColor = .tertiaryLabelColor
        toolTip = tip
        target = self
        action = #selector(fire)
    }

    @objc private func fire() { run() }
}

/// The small state label at the bottom of every Settings window.
@MainActor
func stateLabel() -> NSTextField {
    let label = NSTextField(wrappingLabelWithString: ProtoState.shared.label)
    label.font = .systemFont(ofSize: 9)
    label.textColor = .tertiaryLabelColor
    return label
}
