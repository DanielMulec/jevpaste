import Foundation
import SmartPasteCore

/// What the fake clipboard and inserter did, in order, with the manual clock's elapsed time.
@MainActor
final class DeliveryLog {
    enum Entry: Equatable {
        case write(String)
        case pasteKeystroke
        case restore
    }

    private let clock: ManualClock
    private(set) var entries: [(entry: Entry, at: Duration)] = []

    init(clock: ManualClock) {
        self.clock = clock
    }

    var steps: [Entry] { entries.map(\.entry) }

    func record(_ entry: Entry) {
        entries.append((entry, clock.elapsed))
    }

    func time(of entry: Entry) -> Duration? {
        entries.first { $0.entry == entry }?.at
    }
}

@MainActor
final class FakeHotkey: Hotkey {
    private var onPress: (@MainActor () -> Void)?

    func startListening(onPress: @escaping @MainActor () -> Void) {
        self.onPress = onPress
    }

    func press() {
        onPress?()
    }
}

/// An in-memory pasteboard. Changes reach observers only when a test calls `deliverPendingChanges()`, like the
/// real adapter's polling, which cannot interleave with a main-actor call.
@MainActor
final class FakeClipboard: Clipboard {
    private let log: DeliveryLog
    private var observer: (@MainActor (ClipboardChange) -> Void)?
    private var pendingChanges: [ClipboardChange] = []
    private(set) var changeCount = 0
    private(set) var contents: ClipboardSnapshot

    init(log: DeliveryLog, initialText: String) {
        self.log = log
        contents = Self.snapshot(of: initialText)
    }

    static let plainTextType = "public.utf8-plain-text"

    static func snapshot(of text: String) -> ClipboardSnapshot {
        ClipboardSnapshot(items: [[Self.plainTextType: Data(text.utf8), "public.rtf": Data([0x7B, 0x5C])]])
    }

    func snapshot() -> ClipboardSnapshot {
        contents
    }

    func write(_ text: String) -> Int {
        log.record(.write(text))
        return replaceContents(with: ClipboardSnapshot(items: [[Self.plainTextType: Data(text.utf8)]]), text)
    }

    func restore(_ snapshot: ClipboardSnapshot) -> Int {
        log.record(.restore)
        let text = snapshot.items.first?[Self.plainTextType].flatMap { String(bytes: $0, encoding: .utf8) }
        return replaceContents(with: snapshot, text)
    }

    /// Like the real adapter, observation starts from the current change count: earlier changes are never reported.
    func startObservingChanges(_ onChange: @escaping @MainActor (ClipboardChange) -> Void) {
        if let text = foreignCopyJustBeforeObservationStarts {
            _ = replaceContents(with: Self.snapshot(of: text), text)
        }
        observer = onChange
        pendingChanges = []
    }

    /// Someone else copies this text at the last instant before observation starts (the launch race).
    var foreignCopyJustBeforeObservationStarts: String?

    /// The plain text on the clipboard now, as the real adapter's `currentItem()` would read it (unmarked).
    func currentItem() -> ClipboardItem? {
        contents.items.first?[Self.plainTextType].flatMap { String(bytes: $0, encoding: .utf8) }
            .map { ClipboardItem(text: $0) }
    }

    /// Someone else copies `text`; observers hear about it immediately.
    func simulateForeignCopy(_ text: String, isConcealed: Bool = false) {
        _ = replaceContents(with: Self.snapshot(of: text), text, isConcealed: isConcealed)
        deliverPendingChanges()
    }

    /// Someone else copies `text`; observers hear about it only at the next `deliverPendingChanges()`.
    func simulateForeignCopyNotYetObserved(_ text: String) {
        _ = replaceContents(with: Self.snapshot(of: text), text)
    }

    func deliverPendingChanges() {
        let changes = pendingChanges
        pendingChanges = []
        for change in changes {
            observer?(change)
        }
    }

    private func replaceContents(with snapshot: ClipboardSnapshot, _ text: String?, isConcealed: Bool = false) -> Int {
        contents = snapshot
        changeCount += 1
        let item = text.map { ClipboardItem(text: $0, isConcealed: isConcealed) }
        pendingChanges.append(ClipboardChange(changeCount: changeCount, item: item))
        return changeCount
    }
}

@MainActor
final class FakeTargetResolver: TargetResolver {
    var focusedTarget: BoundTarget?
    /// The app reported as waking its Accessibility when nothing is focused.
    private let wakingApplication: String?

    init(focusedTarget: BoundTarget?, wakingApplication: String? = nil) {
        self.focusedTarget = focusedTarget
        self.wakingApplication = wakingApplication
    }

    func resolveFocusedTarget() -> TargetResolution {
        if let focusedTarget { return .resolved(focusedTarget) }
        return wakingApplication.map { .waking(applicationName: $0) } ?? .noEditableTarget
    }

    func isStillFocused(_ target: TargetIdentity) -> Bool {
        focusedTarget?.identity == target
    }
}

@MainActor
final class FakeInserter: Inserter {
    private let log: DeliveryLog

    init(log: DeliveryLog) {
        self.log = log
    }

    func postPasteKeystroke() {
        log.record(.pasteKeystroke)
    }
}
