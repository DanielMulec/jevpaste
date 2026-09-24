import AppKit

/// One history row: a text symbol, the first line, "N lines" for a multi-line item, a checkmark on the Active
/// Item's row, and a ✕ that appears while the pointer is over the row.
@MainActor
final class HistoryRowCell: NSTableCellView {
    var onDelete: (@MainActor () -> Void)?
    var isHovered = false {
        didSet { deleteButton.isHidden = !isHovered }
    }

    private let deleteButton = NSButton()

    init(row: HistoryRow) {
        super.init(frame: .zero)
        let symbol = Self.symbol(row.detail == nil ? "textformat" : "text.alignleft", size: 13)
        symbol.contentTintColor = .secondaryLabelColor
        let title = NSTextField(labelWithString: row.title)
        title.font = .systemFont(ofSize: 13.5)
        title.lineBreakMode = .byTruncatingTail
        title.maximumNumberOfLines = 1
        title.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textField = title
        imageView = symbol
        var views: [NSView] = [symbol, title, NSView()]
        if let detail = row.detail {
            let detailField = NSTextField(labelWithString: detail)
            detailField.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
            detailField.textColor = .secondaryLabelColor
            views.append(detailField)
        }
        if row.isActive {
            let check = Self.symbol("checkmark.circle.fill", size: 14)
            check.contentTintColor = .controlAccentColor
            check.toolTip = "Active — ⌘⇧V pastes this"
            views.append(check)
        }
        configureDeleteButton()
        views.append(deleteButton)
        let stack = NSStackView(views: views)
        stack.orientation = .horizontal
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 0, left: 6, bottom: 0, right: 4)
        addFillingSubview(stack)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    /// White text and symbols on the accent-coloured highlight, as in every macOS list.
    override var backgroundStyle: NSView.BackgroundStyle {
        didSet {
            let emphasized = backgroundStyle == .emphasized
            imageView?.contentTintColor = emphasized ? .alternateSelectedControlTextColor : .secondaryLabelColor
            deleteButton.contentTintColor = emphasized ? .alternateSelectedControlTextColor : .tertiaryLabelColor
        }
    }

    private func configureDeleteButton() {
        let configuration = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
        deleteButton.image = NSImage(
            systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Delete from History"
        )?.withSymbolConfiguration(configuration)
        deleteButton.isBordered = false
        deleteButton.imagePosition = .imageOnly
        deleteButton.contentTintColor = .tertiaryLabelColor
        deleteButton.toolTip = "Delete from History (⌘⌫)"
        deleteButton.isHidden = true
        deleteButton.target = self
        deleteButton.action = #selector(deleteClicked)
    }

    @objc private func deleteClicked() {
        onDelete?()
    }

    private static func symbol(_ name: String, size: Double) -> NSImageView {
        let configuration = NSImage.SymbolConfiguration(pointSize: size, weight: .regular)
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration)
        let view = NSImageView(image: image ?? NSImage())
        view.setContentHuggingPriority(.required, for: .horizontal)
        return view
    }
}
