// PROTOTYPE — history-probe, never merged
import AppKit
import SmartPasteCore
import os

/// The three history-surface variants Daniel compares; switched from the status-item menu.
enum ProbeVariant: String, CaseIterable {
    case menu = "A — Menu"
    case panel = "B — Panel list"
    case search = "C — Search-first"
}

/// The probe's controller: owns the variant, reads and edits the real Clipboard History, selects an item as the
/// Active Item through the probe-only `CopyCapture.select(_:)`, and surfaces every Active Item change.
@MainActor
final class HistoryProbe {
    static let log = Logger(subsystem: "jevpaste", category: "HistoryProbe")
    private static let variantKey = "historyProbeVariant"
    private static let menuBarTitleLength = 24

    let history: any HistoryRepository
    let capture: CopyCapture
    let failNext: FailNextDecisionService
    private let notices: IndicatorNoticeSurface
    private weak var statusItem: NSStatusItem?
    private let focusReturn: TargetAppFocusReturn
    private lazy var listPanel = HistoryListPanel(probe: self, anchorFrame: statusItemFrame)
    private lazy var searchPanel = HistorySearchPanel(probe: self, anchorFrame: statusItemFrame)
    private let statusItemFrame: @MainActor () -> NSRect?

    var variant: ProbeVariant {
        didSet {
            UserDefaults.standard.set(variant.rawValue, forKey: Self.variantKey)
            Self.log.notice("variant \(self.variant.rawValue, privacy: .public)")
            refreshMenuBarTitle()
        }
    }

    init(
        history: any HistoryRepository, capture: CopyCapture, notices: IndicatorNoticeSurface,
        statusItem: NSStatusItem, statusItemFrame: @escaping @MainActor () -> NSRect?,
        focusReturn: TargetAppFocusReturn, failNext: FailNextDecisionService
    ) {
        self.history = history
        self.capture = capture
        self.notices = notices
        self.statusItem = statusItem
        self.statusItemFrame = statusItemFrame
        self.focusReturn = focusReturn
        self.failNext = failNext
        let stored = UserDefaults.standard.string(forKey: Self.variantKey)
        variant = stored.flatMap(ProbeVariant.init(rawValue:)) ?? .menu
        capture.onActiveItemChange = { [weak self] item in self?.activeItemChanged(item) }
        refreshMenuBarTitle()
    }

    // MARK: history operations shared by every variant

    func items() -> [ClipboardItem] {
        history.items()
    }

    func isActive(_ item: ClipboardItem) -> Bool {
        guard let active = capture.activeItem else { return false }
        return Self.identity(active.text) == Self.identity(item.text)
    }

    func select(_ item: ClipboardItem, from surface: String) {
        Self.log.notice("selected from \(surface, privacy: .public)")
        capture.select(item)
    }

    func delete(_ item: ClipboardItem) {
        Self.log.notice("deleted one item")
        history.delete(item)
    }

    func clearAll() {
        Self.log.notice("cleared all")
        history.clearAll()
    }

    // MARK: panels (B and C)

    func openPanel() {
        let target = NSWorkspace.shared.frontmostApplication?.processIdentifier
        // After the menu has closed, so the key panel is not dismissed by the menu's own tracking end.
        DispatchQueue.main.async { [self] in
            switch variant {
            case .panel: listPanel.open(returningFocusTo: target)
            case .search: searchPanel.open(returningFocusTo: target)
            case .menu: break
            }
        }
    }

    /// Hands focus back to the app that was frontmost when the panel opened (Esc or a selection; not click-away).
    func returnFocus(to processIdentifier: Int32?) {
        guard let processIdentifier else { return }
        focusReturn.returnFocus(to: processIdentifier) { result in
            Self.log.notice("focus return \(String(describing: result), privacy: .public)")
        }
    }

    // MARK: surfacing the Active Item

    static func firstLine(of text: String, limit: Int = 60) -> String {
        let line = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? text
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.count > limit ? String(trimmed.prefix(limit - 1)) + "…" : trimmed
    }

    static func label(for item: ClipboardItem, limit: Int = 60) -> String {
        item.isConcealed ? "(concealed item)" : firstLine(of: item.text, limit: limit)
    }

    private static func identity(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func activeItemChanged(_ item: ClipboardItem) {
        Self.log.notice("active item changed")
        notices.show(
            IndicatorNotice(
                symbolName: "pin.fill", text: "Active: " + Self.label(for: item), for: .milliseconds(2500)
            )
        )
        refreshMenuBarTitle()
    }

    private func refreshMenuBarTitle() {
        guard let button = statusItem?.button else { return }
        if variant == .search, let active = capture.activeItem {
            statusItem?.length = NSStatusItem.variableLength
            button.imagePosition = .imageLeft
            button.title = " " + Self.label(for: active, limit: Self.menuBarTitleLength)
        } else {
            button.title = ""
            button.imagePosition = .imageOnly
            statusItem?.length = NSStatusItem.squareLength
        }
    }
}
