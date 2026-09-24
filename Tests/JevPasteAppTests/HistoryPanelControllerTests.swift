import Foundation
import HistoryStore
import SmartPasteCore
import Testing

@testable import JevPasteApp

/// The history panel's logic over a recording surface, real SQLite history in a scratch file, a real
/// `CopyCapture` and a stepped clock. Three synthetic copies: ONE, TWO, THREE (newest, Active).
@MainActor
final class HistoryPanelControllerTests {
    private static let chrome: Int32 = 4242
    private static let one = ClipboardItem(text: "JEVPASTE-HIST-ONE\nalpha.one@example.org")
    private static let two = ClipboardItem(text: "JEVPASTE-HIST-TWO\nbeta.two@example.net")
    private static let three = ClipboardItem(text: "JEVPASTE-HIST-THREE\ngamma.three@example.com")

    private let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("jevpaste-history-panel-\(UUID().uuidString)", isDirectory: true)
    private let surface = RecordingHistoryPanelSurface()
    private let indicator = RecordingIndicatorSurface()
    private let activator = FakeApplicationActivator()
    private let clock = SteppedClock()
    private let clipboard = CopyingClipboard()
    private let history: any HistoryRepository
    private let capture: CopyCapture
    private let controller: HistoryPanelController

    init() throws {
        history = try SQLiteHistoryRepository(
            fileURL: directory.appendingPathComponent("history.sqlite"), retentionLimit: 500, onFailure: { _ in }
        )
        capture = CopyCapture(clipboard: clipboard, history: history)
        activator.frontmostProcessIdentifier = Self.chrome
        controller = HistoryPanelController(
            surface: surface, history: history, capture: capture,
            focusReturn: TargetAppFocusReturn(activator: activator, clock: clock), activator: activator,
            notices: IndicatorNoticeSurface(wrapping: indicator, clock: clock)
        )
        for item in [Self.one, Self.two, Self.three] {
            clipboard.copy(item.text)
        }
    }

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }

    private static let allTitles = ["JEVPASTE-HIST-THREE", "JEVPASTE-HIST-TWO", "JEVPASTE-HIST-ONE"]

    @Test func opensWithEveryItemNewestFirstTheActiveItemPinnedAndTheFirstRowHighlighted() {
        controller.open()

        #expect(surface.rowTitles == Self.allTitles)
        #expect(surface.shown?.rows.map(\.isActive) == [true, false, false])
        #expect(
            surface.shown?.activeItem
                == .text(lines: ["JEVPASTE-HIST-THREE", "gamma.three@example.com"], moreLineCount: 0))
        #expect(surface.highlighted == 0)
    }

    @Test func typingFiltersAsYouTypeAndHighlightsTheFirstMatch() {
        controller.open()

        surface.send(.moveDown, .queryChanged("hist-t"))
        #expect(surface.rowTitles == ["JEVPASTE-HIST-THREE", "JEVPASTE-HIST-TWO"])
        #expect(surface.highlighted == 0)

        surface.send(.queryChanged("nothing like it"))
        #expect(surface.rowTitles == [])
        #expect(surface.highlighted == nil)
        #expect(surface.shown?.emptyMessage == "No Matches")
    }

    @Test func arrowsMoveTheHighlightAndStopAtBothEnds() {
        controller.open()

        surface.send(.moveUp)
        #expect(surface.highlighted == 0)
        surface.send(.moveDown, .moveDown, .moveDown)
        #expect(surface.highlighted == 2)
    }

    @Test func enterMakesTheHighlightedItemActiveClosesReturnsFocusAndSaysSo() {
        controller.open()

        surface.send(.moveDown, .moveDown, .chooseHighlighted)

        #expect(capture.activeItem == Self.one)
        #expect(history.items() == [Self.three, Self.two, Self.one])
        #expect(surface.shown == nil)
        #expect(activator.activated == [Self.chrome])
        #expect(indicator.displayed == IndicatorContent(symbolName: "pin.fill", text: "Active: JEVPASTE-HIST-ONE"))
    }

    @Test func clickingARowOfAFilteredListSelectsThatRowsItem() {
        controller.open()

        surface.send(.queryChanged("two"), .choose(row: 0))

        #expect(capture.activeItem == Self.two)
        #expect(surface.shown == nil)
    }

    @Test func escapeClosesAndReturnsFocusWithoutAnyChange() {
        controller.open()

        surface.send(.moveDown, .dismiss(.escape))

        #expect(surface.shown == nil)
        #expect(capture.activeItem == Self.three)
        #expect(activator.activated == [Self.chrome])
        #expect(indicator.displayed == nil)
    }

    @Test func clickAwayClosesWithoutFocusReturnOrAnyChange() {
        controller.open()

        surface.send(.moveDown, .dismiss(.clickAway))

        #expect(surface.shown == nil)
        #expect(capture.activeItem == Self.three)
        #expect(activator.activated.isEmpty)
    }

    @Test func deletingTheHighlightedRowKeepsTheHighlightInPlaceAndClampsAtTheEnd() {
        controller.open()

        surface.send(.moveDown, .deleteHighlighted)
        #expect(surface.rowTitles == ["JEVPASTE-HIST-THREE", "JEVPASTE-HIST-ONE"])
        #expect(surface.highlighted == 1)

        surface.send(.deleteHighlighted)
        #expect(surface.rowTitles == ["JEVPASTE-HIST-THREE"])
        #expect(surface.highlighted == 0)
        #expect(history.items() == [Self.three])
    }

    @Test func deletingTheActiveItemsRowKeepsItPinnedAndActive() {
        controller.open()

        surface.send(.delete(row: 0))

        #expect(surface.rowTitles == ["JEVPASTE-HIST-TWO", "JEVPASTE-HIST-ONE"])
        #expect(
            surface.shown?.activeItem
                == .text(lines: ["JEVPASTE-HIST-THREE", "gamma.three@example.com"], moreLineCount: 0))
        #expect(capture.activeItem == Self.three)
    }

    @Test func clearAllAsksFirstAndCancelKeepsEverything() {
        controller.open()

        surface.send(.clearAllRequested)
        #expect(surface.clearAllQuestion == 3)
        #expect(history.items().count == 3)

        surface.send(.clearAllCancelled)
        #expect(surface.clearAllQuestion == nil)
        #expect(history.items().count == 3)
    }

    @Test func confirmedClearAllEmptiesHistoryButKeepsTheActiveItem() {
        controller.open()

        surface.send(.clearAllRequested, .clearAllConfirmed)

        #expect(history.items().isEmpty)
        #expect(surface.rowTitles == [])
        #expect(surface.shown?.emptyMessage == "No History Yet")
        #expect(surface.clearAllQuestion == nil)
        #expect(capture.activeItem == Self.three)
    }

    @Test func aConfirmationWithoutAQuestionClearsNothing() {
        controller.open()

        surface.send(.clearAllConfirmed)

        #expect(history.items().count == 3)
    }

    @Test func escapeWhileAskingOnlyEndsTheQuestion() {
        controller.open()

        surface.send(.clearAllRequested, .dismiss(.escape))

        #expect(surface.clearAllQuestion == nil)
        #expect(surface.shown != nil)
        #expect(history.items().count == 3)
    }

    @Test func aCopyWhileOpenRefreshesTheRowsAndTheActiveItemWithoutANote() {
        controller.open()

        clipboard.copy("JEVPASTE-HIST-FOUR\ndelta.four@example.com")

        #expect(surface.rowTitles == ["JEVPASTE-HIST-FOUR"] + Self.allTitles)
        #expect(surface.shown?.rows.first?.isActive == true)
        #expect(indicator.displayed == nil)
    }

    @Test func eventsAfterClosingAreIgnored() {
        controller.open()
        surface.send(.dismiss(.clickAway))

        surface.send(.chooseHighlighted, .deleteHighlighted, .clearAllRequested, .clearAllConfirmed)
        clipboard.copy("JEVPASTE-HIST-FOUR")

        #expect(surface.shown == nil)
        #expect(capture.activeItem == ClipboardItem(text: "JEVPASTE-HIST-FOUR"))
        #expect(history.items().count == 4)
    }

    @Test func openingWhileOpenKeepsTheOpenPanelAsItIs() {
        controller.open()
        surface.send(.queryChanged("two"))

        controller.open()

        #expect(surface.openCount == 1)
        #expect(surface.rowTitles == ["JEVPASTE-HIST-TWO"])
    }
}
