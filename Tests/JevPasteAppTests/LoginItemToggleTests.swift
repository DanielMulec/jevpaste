import Testing

@testable import JevPasteApp

/// "Open at Login" in the status-item menu always reflects the system's login-item status and toggles it.
@MainActor
struct LoginItemToggleTests {
    private struct RegistrationRefused: Error {}

    private let screen = RecordingIndicatorSurface()
    private let clock = SteppedClock()
    private let service = FakeLoginItemService()
    private let toggle: LoginItemToggle

    init() {
        toggle = LoginItemToggle(service: service, notices: IndicatorNoticeSurface(wrapping: screen, clock: clock))
    }

    @Test(arguments: [
        (LoginItemStatus.enabled, LoginItemMenuState(title: "Open at Login", check: .checked)),
        (.notRegistered, LoginItemMenuState(title: "Open at Login", check: .unchecked)),
        (.notFound, LoginItemMenuState(title: "Open at Login", check: .unchecked)),
        (
            .requiresApproval,
            LoginItemMenuState(title: "Open at Login — approve in System Settings", check: .awaitingApproval)
        ),
    ])
    func theMenuItemShowsTheSystemStatus(status: LoginItemStatus, menuState: LoginItemMenuState) {
        service.status = status

        #expect(toggle.menuState == menuState)
    }

    @Test(arguments: [LoginItemStatus.notRegistered, .notFound])
    func choosingItWhileOffRegisters(status: LoginItemStatus) {
        service.status = status
        toggle.toggle()

        #expect(service.calls == [.register])
        #expect(toggle.menuState.check == .checked)
        #expect(screen.displayed == nil)
    }

    @Test func choosingItWhileOnUnregisters() {
        service.status = .enabled
        toggle.toggle()

        #expect(service.calls == [.unregister])
        #expect(toggle.menuState.check == .unchecked)
    }

    @Test func choosingItWhileAwaitingApprovalOpensLoginItemsSettings() {
        service.status = .requiresApproval
        toggle.toggle()

        #expect(service.calls == [.openLoginItemsSettings])
    }

    @Test func aRefusedChangeShowsANoticeAndLeavesTheStatus() {
        service.failure = RegistrationRefused()
        toggle.toggle()

        #expect(screen.displayed?.text == "Open at Login could not be changed")
        #expect(toggle.menuState.check == .unchecked)
        clock.step(by: .seconds(5))
        #expect(screen.displayed == nil)
    }

    @Test func aRegistrationThatNeedsApprovalSaysWhereToApprove() {
        service.statusAfterRegistering = .requiresApproval
        toggle.toggle()

        #expect(screen.displayed?.text == "Approve JevPaste in Settings › General › Login Items")
        #expect(toggle.menuState.check == .awaitingApproval)
    }
}

/// Stands in for `SMAppService.mainApp`: records calls and moves the status like the system would.
@MainActor
final class FakeLoginItemService: LoginItemService {
    enum Call: Equatable {
        case register
        case unregister
        case openLoginItemsSettings
    }

    var status = LoginItemStatus.notRegistered
    var statusAfterRegistering = LoginItemStatus.enabled
    var failure: (any Error)?
    private(set) var calls: [Call] = []

    func register() throws {
        calls.append(.register)
        if let failure { throw failure }
        status = statusAfterRegistering
    }

    func unregister() throws {
        calls.append(.unregister)
        if let failure { throw failure }
        status = .notRegistered
    }

    func openLoginItemsSettings() {
        calls.append(.openLoginItemsSettings)
    }
}
