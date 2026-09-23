import AppKit

/// One row of the Candidate Chooser: a single truncating line of Candidate text, highlighted while selected; a
/// click on it (the first one too, without activating the app) chooses it.
@MainActor
final class ChooserRowView: FirstClickView {
    var isSelected = false {
        didSet {
            layer?.backgroundColor = isSelected ? NSColor.selectedContentBackgroundColor.cgColor : nil
            textField.textColor = isSelected ? .alternateSelectedControlTextColor : .labelColor
        }
    }

    private let textField: NSTextField

    init(text: String) {
        textField = NSTextField(labelWithString: text)
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 5
        textField.font = .systemFont(ofSize: NSFont.systemFontSize)
        textField.lineBreakMode = .byTruncatingTail
        textField.maximumNumberOfLines = 1
        textField.translatesAutoresizingMaskIntoConstraints = false
        addSubview(textField)
        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            textField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            textField.topAnchor.constraint(equalTo: topAnchor, constant: 3),
            textField.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -3),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }
}
