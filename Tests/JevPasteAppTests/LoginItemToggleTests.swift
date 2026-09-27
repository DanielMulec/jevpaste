import Testing

@testable import JevPasteApp

/// "Open at Login" in Settings › General always reflects the system's login-item status and toggles it.
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
        (LoginItemStatus.enabled, LoginItemSwitchState.enabled), (.notRegistered, .disabled), (.notFound, .disabled),
        (.requiresApproval, .awaitingApproval),
    ])
    func theSwitchShowsTheSystemStatus(status: LoginItemStatus, switchState: LoginItemSwitchState) {
        service.status = status

        #expect(toggle.switchState == switchState)
    }

    @Test(arguments: [LoginItemStatus.notRegistered, .notFound])
    func choosingItWhileOffRegisters(status: LoginItemStatus) {
        service.status = status
        toggle.toggle()

        #expect(service.calls == [.register])
        #expect(toggle.switchState == .enabled)
        #expect(screen.displayed == nil)
    }

    @Test func choosingItWhileOnUnregisters() {
        service.status = .enabled
        toggle.toggle()

        #expect(service.calls == [.unregister])
        #expect(toggle.switchState == .disabled)
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
        #expect(toggle.switchState == .disabled)
        clock.step(by: .seconds(5))
        #expect(screen.displayed == nil)
    }

    @Test func aRegistrationThatNeedsApprovalSaysWhereToApprove() {
        service.statusAfterRegistering = .requiresApproval
        toggle.toggle()

        #expect(screen.displayed?.text == "Approve JevPaste in Settings › General › Login Items")
        #expect(toggle.switchState == .awaitingApproval)
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
