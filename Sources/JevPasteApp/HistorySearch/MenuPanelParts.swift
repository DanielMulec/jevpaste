import AppKit

/// Measures shared by the menu-shaped panel's lines, as in a real menu.
enum MenuMetrics {
    /// The leading slot (Active Item dot) starts here and is this wide; titles start at `titleInset`.
    static let leadingSlotInset = 6.0
    static let leadingSlotWidth = 14.0
    static let titleInset = 25.0
    static let itemHeight = 22.0
    static let rowHeight = 38.0
    /// Lines sit this far inside the panel's edge (the highlight's margin).
    static let lineInset = 5.0
}

/// A menu separator line.
final class MenuSeparatorView: NSView {
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
    required init?(coder: NSCoder) {
        nil
    }
}

/// A dim, non-interactive line at the titles' inset: "5 of 12 matches", "No matching Clipboard Items".
final class MenuHeaderView: NSView {
    init(_ text: String) {
        super.init(frame: .zero)
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = .secondaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: MenuMetrics.titleInset),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -9),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 3),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -3),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }
}

extension NSColor {
    /// Darkens (dark) or lightens (light) the panel's `.menu` material, which renders lighter than a real menu's.
    static let menuPanelTint = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor.black.withAlphaComponent(0.45) : NSColor.white.withAlphaComponent(0.3)
    }
}
