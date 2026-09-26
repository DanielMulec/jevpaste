import AppKit

/// Settings › Full History: every Clipboard Item as a two-line row with the "Active" tag and a ✕ to delete it, the
/// count, and Clear History… behind a confirmation sheet (Cancel is the default button).
@MainActor
final class FullHistorySettingsViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    private static let listHeight = 330.0

    private let list: FullHistoryList
    private let table = NSTableView()
    private let countField = NSTextField(labelWithString: "")

    init(list: FullHistoryList) {
        self.list = list
        super.init(nibName: nil, bundle: nil)
        list.onChange = { [weak self] in self?.redraw() }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func loadView() {
        table.addTableColumn(NSTableColumn(identifier: .init("item")))
        table.headerView = nil
        table.rowHeight = 36
        table.style = .inset
        table.usesAlternatingRowBackgroundColors = true
        table.dataSource = self
        table.delegate = self
        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        let clearButton = NSButton(title: "Clear History…", target: self, action: #selector(askToClear))
        countField.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        countField.textColor = .secondaryLabelColor
        let footer = NSStackView(views: [countField, NSView(), clearButton])
        for part in [scroll, footer] as [NSView] {
            part.translatesAutoresizingMaskIntoConstraints = false
            part.widthAnchor.constraint(equalToConstant: SettingsLayout.contentWidth).isActive = true
        }
        scroll.heightAnchor.constraint(equalToConstant: Self.listHeight).isActive = true
        view = SettingsLayout.column([scroll, footer], spacing: 8)
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        list.reload()
        redraw()
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        list.rows.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard list.rows.indices.contains(row) else { return nil }
        let entry = list.rows[row]
        let title = NSTextField(labelWithString: entry.title)
        title.lineBreakMode = .byTruncatingTail
        title.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let detail = NSTextField(labelWithString: entry.detail)
        detail.font = .systemFont(ofSize: 11)
        detail.textColor = .secondaryLabelColor
        let texts = NSStackView(views: [title, detail])
        texts.orientation = .vertical
        texts.alignment = .leading
        texts.spacing = 1
        var views: [NSView] = [texts, NSView()]
        if entry.isActive { views.append(ActiveTagView()) }
        let deleteButton = NSButton(
            image: NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Delete") ?? NSImage(),
            target: self, action: #selector(deleteRow)
        )
        deleteButton.isBordered = false
        deleteButton.contentTintColor = .tertiaryLabelColor
        deleteButton.toolTip = "Delete from Clipboard History"
        deleteButton.tag = row
        views.append(deleteButton)
        let stack = NSStackView(views: views)
        stack.edgeInsets = NSEdgeInsets(top: 0, left: 4, bottom: 0, right: 4)
        return stack
    }

    private func redraw() {
        guard isViewLoaded else { return }
        table.reloadData()
        countField.stringValue = list.countText
    }

    @objc private func deleteRow(_ sender: NSButton) {
        list.delete(row: sender.tag)
        redraw()
    }

    @objc private func askToClear() {
        guard let window = view.window, !list.rows.isEmpty else { return }
        let alert = NSAlert()
        alert.messageText = "Clear History?"
        alert.informativeText =
            "All \(list.countText) are removed from Clipboard History. The Active Item stays Active. "
            + "This cannot be undone."
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Clear History").hasDestructiveAction = true
        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertSecondButtonReturn else { return }
            self?.list.clearAll()
            self?.redraw()
        }
    }
}

/// The "Active" capsule on the Active Item's row.
final class ActiveTagView: NSTextField {
    init() {
        super.init(frame: .zero)
        stringValue = "Active"
        isEditable = false
        isBordered = false
        drawsBackground = false
        font = .systemFont(ofSize: 10, weight: .semibold)
        textColor = .controlAccentColor
        alignment = .center
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.18).cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override var intrinsicContentSize: NSSize {
        let size = super.intrinsicContentSize
        return NSSize(width: size.width + 12, height: 16)
    }
}
