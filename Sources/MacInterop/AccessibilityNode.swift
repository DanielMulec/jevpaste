/// The text attributes of an Accessibility element that Target resolution reads.
enum AccessibilityTextAttribute: String {
    case role = "AXRole"
    case subrole = "AXSubrole"
    case title = "AXTitle"
    case description = "AXDescription"
    case value = "AXValue"
    case placeholder = "AXPlaceholderValue"
}

/// One element of an app's Accessibility tree, as far as Target resolution needs it.
///
/// The seam between the resolver's rules and the Accessibility API: `AXElementNode` reads a live `AXUIElement`,
/// tests build an in-memory tree.
@MainActor
protocol AccessibilityNode {
    /// A text attribute, or `nil` when the element does not offer it or it is not text.
    func text(of attribute: AccessibilityTextAttribute) -> String?
    var parent: Self? { get }
    /// The first `limit` children; an element may have thousands.
    func children(upTo limit: Int) -> [Self]
    /// The element that labels this one (`AXTitleUIElement`), such as an HTML `<label>`.
    var titleElement: Self? { get }
    /// Whether `AXSelectedTextRange` is settable: the mark of an editable element with a non-text role.
    var isSelectedTextRangeSettable: Bool { get }
    /// Whether both refer to the same element of the same app.
    func isSameElement(as other: Self) -> Bool
}

extension AccessibilityNode {
    var role: String? { text(of: .role) }

    /// A secure text field, by subrole or role. Its value is never read.
    var isSecureTextField: Bool {
        text(of: .subrole) == "AXSecureTextField" || role == "AXSecureTextField"
    }

    /// Something the user can type into: a text role, a secure field, or an element with a settable selection
    /// (web `contenteditable`). A just-launched Catalyst app's `iOSContentGroup` is none of these.
    var isEditable: Bool {
        let textRoles: Set = ["AXTextField", "AXTextArea", "AXComboBox"]
        return role.map(textRoles.contains) == true || isSecureTextField || isSelectedTextRangeSettable
    }

    /// Non-empty text of the first attribute in `attributes` that has some.
    func firstText(of attributes: [AccessibilityTextAttribute]) -> String? {
        attributes.lazy.compactMap { text(of: $0) }.first { !$0.isEmpty }
    }
}

/// Bounds for every walk over another app's Accessibility tree, which may be deep, cyclic or huge.
enum AccessibilityWalkLimits {
    static let childrenPerElement = 100
    static let ancestorDepth = 32
}

/// The focused element and the process it belongs to.
struct FocusedElement<Node: AccessibilityNode> {
    let processIdentifier: Int32
    let bundleIdentifier: String?
    let node: Node
}

/// The app in front, named for the user.
struct FrontmostApplication: Equatable {
    let processIdentifier: Int32
    let name: String
}

/// Where the resolver learns what has keyboard focus: the system-wide Accessibility element in the app, a fake
/// in tests.
@MainActor
protocol FocusSource {
    associatedtype Node: AccessibilityNode
    func focusedElement() -> FocusedElement<Node>?
    /// `IsSecureEventInputEnabled()`: some app is taking a password right now.
    var isSecureEventInputEnabled: Bool { get }
    func frontmostApplication() -> FrontmostApplication?
    /// Whether the app's Accessibility is fully on (`AXEnhancedUserInterface` reads `true`).
    func isAccessibilityAwake(in processIdentifier: Int32) -> Bool
    /// Asks the app to turn its Accessibility fully on; `true` when it then reads as on. Its return code is not
    /// trusted: Electron answers "not implemented" and turns it on anyway.
    func wakeAccessibility(in processIdentifier: Int32) -> Bool
}
