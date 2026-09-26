import AppKit

/// Small building blocks shared by the Settings tabs.
@MainActor
enum SettingsLayout {
    static let contentWidth = 572.0

    /// A vertical, leading-aligned stack with the tabs' 24 pt margin.
    static func column(_ views: [NSView], spacing: Double = 14, inset: Double = 24) -> NSStackView {
        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = spacing
        stack.edgeInsets = NSEdgeInsets(top: inset, left: inset, bottom: inset, right: inset)
        return stack
    }

    static func heading(_ text: String, size: Double = 13) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = .systemFont(ofSize: size, weight: .semibold)
        return field
    }

    /// A small secondary text that wraps within `width`.
    static func note(_ text: String, width: Double = contentWidth) -> NSTextField {
        let field = NSTextField(wrappingLabelWithString: text)
        field.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        field.textColor = .secondaryLabelColor
        field.preferredMaxLayoutWidth = width
        return field
    }
}
