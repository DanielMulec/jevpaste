import AppKit

/// Owns the status item (the app icon's glyph as a template image, `StatusItem.png` from the bundle, falling back to
/// the SF Symbol `doc.on.clipboard` when the bundle lacks it, e.g. under `swift run`) and starts Smart Paste. The item
/// has no `NSMenu`: a click opens the History Search panel, which stands in for the menu.
@MainActor
final class MenuBarDelegate: NSObject, NSApplicationDelegate {
    private let options: LaunchOptions
    private var statusItem: NSStatusItem?
    private var smartPaste: SmartPasteApplication?

    init(options: LaunchOptions) {
        self.options = options
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = Self.statusItemImage()
        item.button?.target = self
        item.button?.action = #selector(statusItemClicked)
        // Opens on mouse-down, as a menu does.
        item.button?.sendAction(on: [.leftMouseDown])
        statusItem = item
        smartPaste = SmartPasteApplication(statusItem: item, options: options)
    }

    /// A template image so macOS tints it for light, dark and auto-hiding menu bars; `@2x` is picked up by name.
    private static func statusItemImage() -> NSImage? {
        guard let image = Bundle.main.image(forResource: "StatusItem") else {
            return NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "jevpaste")
        }
        image.isTemplate = true
        image.size = NSSize(width: 18, height: 18)
        image.accessibilityDescription = "jevpaste"
        return image
    }

    @objc private func statusItemClicked() {
        smartPaste?.historySearch.toggle()
    }
}
