import Foundation
import SmartPasteCore
import Testing

@testable import JevPasteApp

/// The History Search panel's logic over a recording surface, in-memory history, a real `CopyCapture` and a stepped
/// clock. Three synthetic copies: ONE, TWO, THREE (newest, Active); Chrome is frontmost when the panel opens.
@MainActor
struct HistorySearchControllerTests {
    private static let chrome: Int32 = 4242
    private static let one = "JEVPASTE-MENU-ONE\nalpha.one@example.org"
    private static let two = "JEVPASTE-MENU-TWO\nbeta.two@example.net"
    private static let three = "JEVPASTE-MENU-THREE\ngamma.three@example.com"

    private let surface = RecordingHistorySearchSurface()
    private let indicator = RecordingIndicatorSurface()
    private let activator = FakeApplicationActivator()
    private let clock = SteppedClock()
    private let clipboard = CopyingClipboard()
    private let scratch: ScratchHistory
    private let destinations = MenuDestinations()
    private let capture: CopyCapture
    private let controller: HistorySearchController

    init() throws {
        scratch = try ScratchHistory()
        capture = CopyCapture(clipboard: clipboard, history: scratch.repository)
        let changes = ActiveItemChanges(capture: capture)
        activator.frontmostProcessIdentifier = Self.chrome
        controller = HistorySearchController(
            surface: surface, history: scratch.repository, capture: capture, changes: changes,
            focusReturn: TargetAppFocusReturn(activator: activator, clock: clock), activator: activator,
            notices: IndicatorNoticeSurface(wrapping: indicator, clock: clock),
            destinations: HistorySearchDestinations(
                openSettings: { [destinations] in destinations.settingsOpenedAt.append($0) },
                quit: { [destinations] in destinations.quitCount += 1 }
            )
        )
        for text in [Self.one, Self.two, Self.three] {
            clipboard.copy(text)
        }
    }

    @Test func opensWithTheActiveItemAsPlaceholderAndOnlySettingsAndQuit() {
        controller.toggle()

        #expect(surface.openCount == 1)
        #expect(surface.shown?.placeholder == "JEVPASTE-MENU-THREE")
        #expect(surface.shown?.menuItems == [.settings, .quit])
        #expect(surface.highlighted == nil)
    }

    @Test func typingListsTheMatchesNewestFirst() {
        controller.toggle()
        surface.send(.queryChanged("jevpaste-menu"))

        #expect(surface.rowTitles == ["JEVPASTE-MENU-THREE", "JEVPASTE-MENU-TWO", "JEVPASTE-MENU-ONE"])
        #expect(surface.shown?.rows.map(\.isActive) == [true, false, false])
    }

    @Test func arrowsWalkTheRowsAndTheItemBlockAndUpFromTheFirstLeavesNothingHighlighted() {
        controller.toggle()
        surface.send(.queryChanged("example.net"), .moveDown)
        #expect(surface.highlighted == .row(0))

        surface.send(.moveDown, .moveDown, .moveDown, .moveDown)
        #expect(surface.highlighted == .menuItem(.quit))

        surface.send(.moveUp, .moveUp, .moveUp, .moveUp)
        #expect(surface.highlighted == nil)
    }

    @Test func enterWithoutAHighlightMakesTheFirstRowActiveClosesReturnsFocusAndSaysSo() {
        controller.toggle()
        surface.send(.queryChanged("alpha"), .confirm)

        #expect(capture.activeItem == ClipboardItem(text: Self.one))
        #expect(surface.shown == nil)
        #expect(activator.activated == [Self.chrome])
        #expect(indicator.displayed == IndicatorContent(symbolName: "pin.fill", text: "Active: JEVPASTE-MENU-ONE"))
    }

    @Test func enterOnTheHighlightedRowOrAClickChoosesThatRow() {
        controller.toggle()
        surface.send(.queryChanged("jevpaste"), .moveDown, .moveDown, .confirm)
        #expect(capture.activeItem == ClipboardItem(text: Self.two))

        controller.toggle()
        surface.send(.queryChanged("jevpaste"), .choose(.row(2)))
        #expect(capture.activeItem == ClipboardItem(text: Self.one))
    }

    @Test func enterWithABlankFieldAndNothingHighlightedDoesNothing() {
        controller.toggle()
        surface.send(.confirm)

        #expect(surface.shown != nil)
        #expect(capture.activeItem == ClipboardItem(text: Self.three))
    }

    @Test func theItemBlockOpensSettingsOrQuitsWithoutChangingTheActiveItem() {
        controller.toggle()
        surface.send(.queryChanged("jevpaste"), .choose(.menuItem(.fullHistory(itemCount: 3))))
        controller.toggle()
        surface.send(.moveDown, .confirm)
        controller.toggle()
        surface.send(.choose(.menuItem(.quit)))

        #expect(destinations.settingsOpenedAt == [.fullHistory, .general])
        #expect(destinations.quitCount == 1)
        #expect(surface.shown == nil)
        #expect(capture.activeItem == ClipboardItem(text: Self.three))
        #expect(activator.activated.isEmpty)
    }

    @Test func oneEscapeClosesEvenWithTextAndReturnsFocusWithoutAnyChange() {
        controller.toggle()
        surface.send(.queryChanged("alpha"), .moveDown, .dismiss(.escape))

        #expect(surface.shown == nil)
        #expect(activator.activated == [Self.chrome])
        #expect(capture.activeItem == ClipboardItem(text: Self.three))
        #expect(indicator.displayed == nil)
    }

    @Test func clickAwayOrTheStatusItemAgainClosesWithoutFocusReturn() {
        controller.toggle()
        surface.send(.dismiss(.clickAway))
        controller.toggle()
        controller.toggle()

        #expect(surface.shown == nil)
        #expect(surface.openCount == 2)
        #expect(activator.activated.isEmpty)
    }

    @Test func aCopyWhileOpenRefreshesThePlaceholderAndTheRows() {
        controller.toggle()
        surface.send(.queryChanged("jevpaste-menu"))
        clipboard.copy("JEVPASTE-MENU-FOUR\ndelta.four@example.com")

        #expect(surface.shown?.placeholder == "JEVPASTE-MENU-FOUR")
        #expect(surface.rowTitles?.first == "JEVPASTE-MENU-FOUR")
        #expect(indicator.displayed == nil)
    }

    @Test func hoverHighlightsAndEventsAfterClosingAreIgnored() {
        controller.toggle()
        surface.send(.queryChanged("jevpaste"), .hover(.row(1)))
        #expect(surface.highlighted == .row(1))

        surface.send(.dismiss(.escape), .choose(.row(0)), .confirm)
        #expect(capture.activeItem == ClipboardItem(text: Self.three))
        #expect(destinations.settingsOpenedAt.isEmpty)
    }
}
