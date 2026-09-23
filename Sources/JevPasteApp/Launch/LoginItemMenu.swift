import AppKit
import ServiceManagement

/// `SMAppService.mainApp`: registers the installed bundle itself as a login item.
struct MainAppLoginItemService: LoginItemService {
    var status: LoginItemStatus {
        switch SMAppService.mainApp.status {
        case .enabled: .enabled
        case .requiresApproval: .requiresApproval
        case .notFound: .notFound
        case .notRegistered: .notRegistered
        @unknown default: .notRegistered
        }
    }

    func register() throws {
        try SMAppService.mainApp.register()
    }

    func unregister() throws {
        try SMAppService.mainApp.unregister()
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}

/// The "Open at Login" menu item: refreshed from `LoginItemToggle` whenever the menu is about to open, toggled on
/// click. AppKit glue, live-proven only.
@MainActor
final class LoginItemMenu: NSObject, NSMenuDelegate {
    let item = NSMenuItem(title: "", action: #selector(chosen), keyEquivalent: "")
    private let toggle: LoginItemToggle

    init(toggle: LoginItemToggle) {
        self.toggle = toggle
        super.init()
        item.target = self
        refresh()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        refresh()
    }

    @objc private func chosen() {
        toggle.toggle()
        refresh()
    }

    private func refresh() {
        let state = toggle.menuState
        item.title = state.title
        switch state.check {
        case .checked: item.state = .on
        case .unchecked: item.state = .off
        case .awaitingApproval: item.state = .mixed
        }
    }
}
