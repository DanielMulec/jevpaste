import Foundation

/// One Clipboard History entry: the Clipboard Item and when it was last copied — `nil` for items kept from before
/// copy times were recorded. The time only describes the entry ("12 min ago"); order comes from the history itself.
public struct HistoryEntry: Equatable, Sendable {
    public let item: ClipboardItem
    public let copiedAt: Date?

    public init(item: ClipboardItem, copiedAt: Date?) {
        self.item = item
        self.copiedAt = copiedAt
    }
}
