import AppKit

/// One highlightable line of the menu-shaped panel: a Clipboard Item as two lines (first line over a dim "4 lines ·
/// 12 min ago", accent dot for the Active Item), or a menu item with an optional right-aligned count. Highlighted
/// with the menu's selection colour; takes the first click into the non-activating panel and reports hovering.
@MainActor
final class MenuLineView: FirstClickView {
    var onHover: (@MainActor () -> Void)?
    var isHighlighted = false {
        didSet { render() }
    }

    private let titleField = NSTextField(labelWithString: "")
    private let detailField = NSTextField(labelWithString: "")
    private let trailingField = NSTextField(labelWithString: "")
    private let dot = NSView()

    /// A Clipboard Item row.
    init(row: HistoryEntryRow) {
        super.init(frame: .zero)
        titleField.stringValue = row.title
        detailField.stringValue = row.detail
        dot.isHidden = !row.isActive
        build(height: MenuMetrics.rowHeight, texts: [titleField, detailField])
    }

    /// A menu item: "Settings…", or "Full history…" with "(40)" at the right.
    init(title: String, trailing: String? = nil) {
        super.init(frame: .zero)
        titleField.stringValue = title
        trailingField.stringValue = trailing ?? ""
        dot.isHidden = true
        build(height: MenuMetrics.itemHeight, texts: [titleField])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func mouseEntered(with event: NSEvent) {
        onHover?()
    }

    private func build(height: Double, texts: [NSTextField]) {
        wantsLayer = true
        layer?.cornerRadius = 5
        titleField.font = .menuFont(ofSize: 0)
        detailField.font = .systemFont(ofSize: 11)
        trailingField.font = .menuFont(ofSize: 0)
        for field in [titleField, detailField] {
            field.lineBreakMode = .byTruncatingTail
            field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        }
        dot.wantsLayer = true
        dot.layer?.cornerRadius = 3
        let textStack = NSStackView(views: texts)
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 1
        for view in [dot, textStack, trailingField] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: height),
            dot.widthAnchor.constraint(equalToConstant: 6),
            dot.heightAnchor.constraint(equalToConstant: 6),
            dot.centerXAnchor.constraint(
                equalTo: leadingAnchor, constant: MenuMetrics.leadingSlotInset + MenuMetrics.leadingSlotWidth / 2),
            dot.centerYAnchor.constraint(equalTo: titleField.centerYAnchor),
            textStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: MenuMetrics.titleInset),
            textStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: trailingField.leadingAnchor, constant: -6),
            trailingField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -MenuMetrics.titleInset),
            trailingField.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        addTrackingArea(
            NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
        )
        render()
    }

    private func render() {
        layer?.backgroundColor = isHighlighted ? NSColor.selectedContentBackgroundColor.cgColor : nil
        titleField.textColor = isHighlighted ? .selectedMenuItemTextColor : .labelColor
        let dim: NSColor = isHighlighted ? .selectedMenuItemTextColor : .secondaryLabelColor
        detailField.textColor = dim
        trailingField.textColor = dim
        dot.layer?.backgroundColor = (isHighlighted ? NSColor.selectedMenuItemTextColor : .controlAccentColor).cgColor
    }
}
