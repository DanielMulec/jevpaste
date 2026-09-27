import AppKit

/// Small building blocks shared by the Settings tabs; every tab is a `page` with the same content inset.
@MainActor
enum SettingsLayout {
    static let pageWidth = 620.0
    /// The margin between the window's edges and every tab's content, footers included.
    static let contentInset = 20.0
    static let contentWidth = pageWidth - 2 * contentInset

    /// A tab's content: `views` stacked top to bottom inside the content inset, on a page of the Settings width.
    /// The views in `fullWidth` span the whole content width (rows with a trailing control, lists, footers).
    static func page(_ views: [NSView], spacing: Double = 14, fullWidth: [NSView] = []) -> NSView {
        let stack = column(views, spacing: spacing)
        let page = NSView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        page.addSubview(stack)
        NSLayoutConstraint.activate([
            page.widthAnchor.constraint(equalToConstant: pageWidth),
            stack.leadingAnchor.constraint(equalTo: page.leadingAnchor, constant: contentInset),
            stack.trailingAnchor.constraint(equalTo: page.trailingAnchor, constant: -contentInset),
            stack.topAnchor.constraint(equalTo: page.topAnchor, constant: contentInset),
            stack.bottomAnchor.constraint(equalTo: page.bottomAnchor, constant: -contentInset),
        ])
        for view in fullWidth {
            view.translatesAutoresizingMaskIntoConstraints = false
            view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        return page
    }

    /// A vertical, leading-aligned stack without margins.
    static func column(_ views: [NSView], spacing: Double = 14) -> NSStackView {
        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = spacing
        return stack
    }

    static func heading(_ text: String, size: Double = 13) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = .systemFont(ofSize: size, weight: .semibold)
        return field
    }

    /// A small secondary text that wraps within the content width.
    static func note(_ text: String) -> NSTextField {
        let field = NSTextField(wrappingLabelWithString: text)
        field.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        field.textColor = .secondaryLabelColor
        field.preferredMaxLayoutWidth = contentWidth
        return field
    }
}
