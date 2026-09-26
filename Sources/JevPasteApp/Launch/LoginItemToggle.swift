import Foundation
import os

/// The system's login-item status for JevPaste (`SMAppService.Status`, without ServiceManagement).
enum LoginItemStatus {
    case enabled
    case notRegistered
    case requiresApproval
    case notFound
}

/// Registers JevPaste to open at login; in the app `SMAppService.mainApp`. The system persists the registration.
@MainActor
protocol LoginItemService {
    var status: LoginItemStatus { get }
    func register() throws
    func unregister() throws
    func openLoginItemsSettings()
}

/// Where the "Open at Login" switch in Settings › General stands, independent of AppKit.
enum LoginItemSwitchState: Equatable {
    case enabled
    case disabled
    /// Registered, but waiting for approval in System Settings: the switch is on and a note says where to approve.
    case awaitingApproval
}

/// "Open at Login" in Settings › General. Nothing is stored here: the state is read from the system every time the
/// tab shows, so it is right after a relaunch or a change in System Settings.
@MainActor
final class LoginItemToggle {
    private static let log = Logger(subsystem: "jevpaste", category: "Launch")
    private static let noticeDuration = Duration.seconds(5)

    private let service: any LoginItemService
    private let notices: IndicatorNoticeSurface

    init(service: any LoginItemService, notices: IndicatorNoticeSurface) {
        self.service = service
        self.notices = notices
    }

    var switchState: LoginItemSwitchState {
        switch service.status {
        case .enabled: .enabled
        case .requiresApproval: .awaitingApproval
        case .notRegistered, .notFound: .disabled
        }
    }

    /// Off → register; on → unregister; awaiting approval → open the Login Items settings where Daniel approves.
    func toggle() {
        let before = service.status
        if before == .requiresApproval { return service.openLoginItemsSettings() }
        do {
            if before == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            Self.log.error("login item change failed with code \((error as NSError).code, privacy: .public)")
            return showNotice("Open at Login could not be changed")
        }
        let after = service.status
        Self.log.notice("login item status \(String(describing: after), privacy: .public)")
        if after == .requiresApproval { showNotice("Approve JevPaste in Settings › General › Login Items") }
    }

    private func showNotice(_ text: String) {
        notices.show(IndicatorNotice(warning: text, for: Self.noticeDuration))
    }
}
