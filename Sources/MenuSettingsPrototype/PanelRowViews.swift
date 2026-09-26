// PROTOTYPE — menu-settings, never merged
import AppKit

/// A menu-looking row for Menu B: leading slot (✓ / dot / kind symbol), title, trailing tagView and age; highlighted
/// with the menu's accent capsule on hover or ↑/↓; takes the first click into the non-activating panel.
@MainActor
final class PanelRow: NSView {
    var onClick: (() -> Void)?
    var onHover: (() -> Void)?
    let clipID: Int?
    var isHighlighted = false { didSet { render() } }

    private let titleField = NSTextField(labelWithString: "")
    private let leading = NSImageView()
    private let tagView = NSImageView()
    private let trailing = NSTextField(labelWithString: "")
    private let makeTitle: (Bool) -> NSAttributedString
    private let makeLeading: (Bool) -> NSImage?
    private let makeTag: (Bool) -> NSImage?
    private let makeTrailing: (Bool) -> NSAttributedString?

    init(clip: ClipItem, query: String, look: RowLook, active: Bool) {
        clipID = clip.id
        makeTitle = { look.title(clip, query: query, active: active, highlighted: $0) }
        makeLeading = { highlighted in
            if look.style == 1 {
                return active ? NSImage(systemSymbolName: "checkmark", accessibilityDescription: "Active Item")?
                    .withSymbolConfiguration(.init(pointSize: 11, weight: .semibold)) : nil
            }
            return look.leadingImage(clip, active: active, highlighted: highlighted)
        }
        makeTag = { look.tagImage(active: active, highlighted: $0) }
        makeTrailing = { look.trailingText(clip, highlighted: $0) }
        super.init(frame: .zero)
        toolTip = clip.text
        build(height: look.rowHeight)
    }

    init(title: @escaping (Bool) -> NSAttributedString,
         trailing: @escaping (Bool) -> NSAttributedString? = { _ in nil }, trailingInset: Double = 9) {
        clipID = nil
        makeTitle = title
        makeLeading = { _ in nil }
        makeTag = { _ in nil }
        makeTrailing = trailing
        super.init(frame: .zero)
        build(height: 22, trailingInset: trailingInset)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    /// Title's leading inset inside the row: 6 + 14 (leading slot) + 5.
    static let titleInset = 25.0

    private func build(height: Double, trailingInset: Double = 9) {
        wantsLayer = true
        layer?.cornerRadius = 5
        titleField.maximumNumberOfLines = 2
        titleField.lineBreakMode = .byTruncatingTail
        titleField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        leading.setContentHuggingPriority(.required, for: .horizontal)
        for view in [leading, titleField, tagView, trailing] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: height),
            leading.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            leading.widthAnchor.constraint(equalToConstant: 14),
            leading.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleField.leadingAnchor.constraint(equalTo: leading.trailingAnchor, constant: 5),
            titleField.centerYAnchor.constraint(equalTo: centerYAnchor),
            trailing.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -trailingInset),
            trailing.centerYAnchor.constraint(equalTo: centerYAnchor),
            tagView.trailingAnchor.constraint(equalTo: trailing.leadingAnchor, constant: -6),
            tagView.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleField.trailingAnchor.constraint(lessThanOrEqualTo: tagView.leadingAnchor, constant: -6),
        ])
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                       owner: self))
        render()
    }

    private func render() {
        layer?.backgroundColor = isHighlighted ? NSColor.selectedContentBackgroundColor.cgColor : nil
        titleField.attributedStringValue = makeTitle(isHighlighted)
        leading.image = makeLeading(isHighlighted)
        leading.contentTintColor = isHighlighted ? .white : .secondaryLabelColor
        tagView.image = makeTag(isHighlighted)
        trailing.attributedStringValue = makeTrailing(isHighlighted) ?? NSAttributedString()
    }

    override func hitTest(_ point: NSPoint) -> NSView? { frame.contains(point) ? self : nil }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseEntered(with event: NSEvent) { onHover?() }
    override func mouseUp(with event: NSEvent) { onClick?() }
}

extension NSView {
    func addFillingSubview(_ subview: NSView) {
        subview.translatesAutoresizingMaskIntoConstraints = false
        addSubview(subview)
        NSLayoutConstraint.activate([
            subview.leadingAnchor.constraint(equalTo: leadingAnchor),
            subview.trailingAnchor.constraint(equalTo: trailingAnchor),
            subview.topAnchor.constraint(equalTo: topAnchor),
            subview.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }
}

/// A menu separator line.
final class MenuSeparator: NSView {
    init() {
        super.init(frame: .zero)
        let line = NSBox()
        line.boxType = .separator
        line.translatesAutoresizingMaskIntoConstraints = false
        addSubview(line)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 11),
            line.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 9),
            line.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -9),
            line.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }
}

/// A dim, non-interactive line: a section header or the prototype's state label.
final class MenuHeader: NSView {
    init(_ text: String, small: Bool = false) {
        super.init(frame: .zero)
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = small ? .systemFont(ofSize: 9) : .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = small ? .tertiaryLabelColor : .secondaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: small ? 9 : 25),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -9),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 3),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -3),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }
}
