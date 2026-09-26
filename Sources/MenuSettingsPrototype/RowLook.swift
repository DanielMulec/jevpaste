// PROTOTYPE — menu-settings, never merged
import AppKit

/// The three row looks (question 2), rendered the same way into `NSMenuItem`s (Menu A) and panel rows (Menu B).
/// 1 = plain line + ✓ column · 2 = two lines + accent dot + match header · 3 = kind symbol, mono preview, "Active" tag.
@MainActor
struct RowLook {
    let style: Int

    var rowHeight: Double { style == 2 ? 38 : 22 }

    /// The dim header above the rows, or nil.
    func header(shown: Int, total: Int) -> String? {
        style == 2 ? "\(shown) of \(total) matches" : nil
    }

    func fullHistoryTitle(total: Int, all: Int, highlighted: Bool = false) -> NSAttributedString {
        let text = NSMutableAttributedString(string: "Full history…", attributes: [
            .font: NSFont.menuFont(ofSize: 0),
            .foregroundColor: highlighted ? NSColor.selectedMenuItemTextColor : NSColor.labelColor,
        ])
        let suffix: String? = switch style {
        case 2: "  (\(all))"
        case 3: "   \(total) matches"
        default: nil
        }
        if let suffix {
            text.append(NSAttributedString(string: suffix, attributes: [
                .font: NSFont.menuFont(ofSize: 0),
                .foregroundColor: highlighted ? NSColor.selectedMenuItemTextColor : NSColor.secondaryLabelColor,
            ]))
        }
        return text
    }

    /// Leading image: nil for style 1 (the menu's ✓ column is used), a dot or blank for 2, the kind symbol for 3.
    func leadingImage(_ item: ClipItem, active: Bool, highlighted: Bool) -> NSImage? {
        switch style {
        case 2:
            return Self.dot(active ? (highlighted ? .white : .controlAccentColor) : .clear)
        case 3:
            let configuration = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
            let image = NSImage(systemSymbolName: item.symbolName, accessibilityDescription: nil)?
                .withSymbolConfiguration(configuration)
            image?.isTemplate = true
            return image
        default:
            return nil
        }
    }

    func title(_ item: ClipItem, query: String, active: Bool, highlighted: Bool) -> NSAttributedString {
        let primary: NSColor = highlighted ? .selectedMenuItemTextColor : .labelColor
        let secondary: NSColor = highlighted ? .selectedMenuItemTextColor.withAlphaComponent(0.8)
            : .secondaryLabelColor
        let line = Self.clip(item.firstLine, to: style == 3 ? 38 : 46)
        switch style {
        case 2:
            let text = NSMutableAttributedString(string: line + "\n", attributes: [
                .font: NSFont.menuFont(ofSize: 0), .foregroundColor: primary,
            ])
            text.append(NSAttributedString(string: item.detailText, attributes: [
                .font: NSFont.systemFont(ofSize: 11), .foregroundColor: secondary,
            ]))
            return text
        case 3:
            let mono = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
            let text = NSMutableAttributedString(string: line, attributes: [.font: mono, .foregroundColor: primary])
            let range = (line as NSString).range(of: query, options: .caseInsensitive)
            if range.location != NSNotFound, !query.isEmpty {
                text.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: 12, weight: .bold), range: range)
            }
            return text
        default:
            return NSAttributedString(string: line, attributes: [
                .font: NSFont.menuFont(ofSize: 0), .foregroundColor: primary,
            ])
        }
    }

    /// Trailing text for style 3 (age), else nil.
    func trailingText(_ item: ClipItem, highlighted: Bool) -> NSAttributedString? {
        guard style == 3 else { return nil }
        return NSAttributedString(string: item.ageText, attributes: [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: highlighted ? NSColor.selectedMenuItemTextColor : NSColor.tertiaryLabelColor,
        ])
    }

    /// The "Active" capsule for style 3.
    func tagImage(active: Bool, highlighted: Bool) -> NSImage? {
        guard style == 3, active else { return nil }
        return Self.capsule("Active", tint: highlighted ? .white : .controlAccentColor)
    }

    /// Title for an `NSMenuItem`: the style's title, plus age and tag glued on with a tab for style 3.
    func menuTitle(_ item: ClipItem, query: String, active: Bool) -> NSAttributedString {
        let text = NSMutableAttributedString(attributedString: title(item, query: query, active: active,
                                                                     highlighted: false))
        guard style == 3 else { return text }
        let paragraph = NSMutableParagraphStyle()
        paragraph.tabStops = [NSTextTab(textAlignment: .right, location: 380)]
        text.append(NSAttributedString(string: "\t"))
        if let tag = tagImage(active: active, highlighted: false) {
            let attachment = NSTextAttachment()
            attachment.image = tag
            attachment.bounds = NSRect(x: 0, y: -3, width: tag.size.width, height: tag.size.height)
            text.append(NSAttributedString(attachment: attachment))
            text.append(NSAttributedString(string: "  "))
        }
        if let age = trailingText(item, highlighted: false) { text.append(age) }
        text.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: text.length))
        return text
    }

    static func clip(_ line: String, to length: Int) -> String {
        line.count > length ? String(line.prefix(length - 1)) + "…" : line
    }

    static func dot(_ color: NSColor) -> NSImage {
        NSImage(size: NSSize(width: 12, height: 12), flipped: false) { rect in
            color.setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: 3, dy: 3)).fill()
            return true
        }
    }

    static func capsule(_ text: String, tint: NSColor) -> NSImage {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10, weight: .semibold), .foregroundColor: tint,
        ]
        let size = (text as NSString).size(withAttributes: attributes)
        let box = NSSize(width: ceil(size.width) + 12, height: 16)
        return NSImage(size: box, flipped: false) { rect in
            tint.withAlphaComponent(0.18).setFill()
            NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8).fill()
            (text as NSString).draw(at: NSPoint(x: 6, y: (rect.height - size.height) / 2), withAttributes: attributes)
            return true
        }
    }
}
