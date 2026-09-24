import AppKit

/// The pinned block at the top of the history panel: a tinted card with the pin symbol, the caption
/// "Active · ⌘⇧V pastes this" and up to three lines of the Active Item.
@MainActor
final class ActiveItemView: NSView {
    /// The symbol that means "Active" wherever jevpaste shows it: this card and the note after a selection.
    nonisolated static let symbolName = "pin.fill"

    private let caption = NSTextField(labelWithString: "ACTIVE  ·  ⌘⇧V PASTES THIS")
    private let lineStack = NSStackView()

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.cornerCurve = .continuous
        caption.font = .systemFont(ofSize: NSFont.smallSystemFontSize - 1, weight: .semibold)
        caption.textColor = .controlAccentColor
        lineStack.orientation = .vertical
        lineStack.alignment = .leading
        lineStack.spacing = 1
        let text = NSStackView(views: [caption, lineStack])
        text.orientation = .vertical
        text.alignment = .leading
        text.spacing = 3
        let row = NSStackView(views: [Self.pinBadge(), text])
        row.orientation = .horizontal
        row.alignment = .top
        row.spacing = 10
        row.edgeInsets = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 12)
        addFillingSubview(row)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override var wantsUpdateLayer: Bool { true }

    /// Resolves the dynamic accent tint for the current appearance (light or dark).
    override func updateLayer() {
        layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.12).cgColor
    }

    func show(_ preview: ActiveItemPreview) {
        for view in lineStack.arrangedSubviews { view.removeFromSuperview() }
        switch preview {
        case .nothing:
            lineStack.addArrangedSubview(Self.line("Nothing copied yet", primary: false))
        case .concealed:
            lineStack.addArrangedSubview(Self.line("Concealed item — not shown", primary: false))
        case .text(let lines, let moreLineCount):
            for (index, text) in lines.enumerated() {
                lineStack.addArrangedSubview(Self.line(text, primary: index == 0))
            }
            if moreLineCount > 0 {
                lineStack.addArrangedSubview(Self.more(moreLineCount))
            }
        }
        needsDisplay = true
    }

    private static func pinBadge() -> NSView {
        let configuration = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        let symbol = NSImageView(
            image: NSImage(systemSymbolName: Self.symbolName, accessibilityDescription: "Active")?
                .withSymbolConfiguration(configuration) ?? NSImage()
        )
        symbol.contentTintColor = .white
        let badge = NSView()
        badge.wantsLayer = true
        badge.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
        badge.layer?.cornerRadius = 14
        badge.translatesAutoresizingMaskIntoConstraints = false
        symbol.translatesAutoresizingMaskIntoConstraints = false
        badge.addSubview(symbol)
        NSLayoutConstraint.activate([
            badge.widthAnchor.constraint(equalToConstant: 28),
            badge.heightAnchor.constraint(equalToConstant: 28),
            symbol.centerXAnchor.constraint(equalTo: badge.centerXAnchor),
            symbol.centerYAnchor.constraint(equalTo: badge.centerYAnchor),
        ])
        return badge
    }

    private static func line(_ text: String, primary: Bool) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = primary ? .systemFont(ofSize: 14, weight: .semibold) : .systemFont(ofSize: 13)
        field.textColor = primary ? .labelColor : .secondaryLabelColor
        field.lineBreakMode = .byTruncatingTail
        field.maximumNumberOfLines = 1
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }

    private static func more(_ count: Int) -> NSTextField {
        let field = NSTextField(labelWithString: count == 1 ? "1 more line" : "\(count) more lines")
        field.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        field.textColor = .tertiaryLabelColor
        return field
    }
}
