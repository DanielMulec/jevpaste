// PROTOTYPE — menu-settings, never merged
import AppKit

/// Shell hooks for screenshots and the question-1 self-test. Env vars:
/// PROTO_OPEN=menu|settings · PROTO_QUERY=<text> · PROTO_SECTION=general|provider|full|key-gateway|key-typesafe ·
/// PROTO_TEST=1 (press Test) · PROTO_SELFTEST=1 (post key events into the open menu and log what happens).
/// The window number of what was opened is written to /tmp/proto-<menu|settings>.wid for `screencapture -l`.
@MainActor
final class ProtoHooks {
    static let shared = ProtoHooks()
    private weak var app: ProtoAppDelegate?
    private let environment = ProcessInfo.processInfo.environment

    func start(app: ProtoAppDelegate) {
        self.app = app
        VariantMenuRefresher.shared.app = app
        if environment["PROTO_SELFTEST"] != nil {
            after(1.0) { self.selfTest() }
            app.openMenuSoon()
            return
        }
        switch environment["PROTO_OPEN"] {
        case "menu":
            after(1.0) { app.openMenu(query: self.environment["PROTO_QUERY"]) }
        case "settings":
            let section: SettingsSection = switch environment["PROTO_SECTION"] {
            case "provider": .provider
            case "full": .fullHistory
            case "key-gateway": .key(.gateway)
            case "key-typesafe": .key(.typesafe)
            default: .general
            }
            if environment["PROTO_EMPTYKEY"] != nil { ProtoState.shared.keys[.gateway] = "" }
            after(0.5) { app.openSettings(section) }
            if environment["PROTO_TEST"] != nil {
                after(1.2) { ProtoState.shared.test(ProtoState.shared.provider) }
            }
        default:
            break
        }
    }

    func after(_ seconds: Double, _ block: @escaping @MainActor () -> Void) {
        let timer = Timer(timeInterval: seconds, repeats: false) { _ in MainActor.assumeIsolated { block() } }
        RunLoop.main.add(timer, forMode: .common)
    }

    func menuWindowOpened(_ window: NSWindow) {
        windowReady(window, name: "menu")
    }

    func windowReady(_ window: NSWindow, name: String) {
        let path = "/tmp/proto-\(name).wid"
        after(0.4) {
            try? "\(window.windowNumber)\n".write(toFile: path, atomically: true, encoding: .utf8)
            NSLog("[proto] hook: %@ window %d → %@", name, window.windowNumber, path)
        }
    }

    // MARK: self-test — synthesised key events, posted to this process, while the menu is open

    private enum Key {
        case text(String, CGKeyCode), down, up, enter, escape
        var code: CGKeyCode {
            switch self {
            case let .text(_, code): code
            case .down: 125
            case .up: 126
            case .enter: 36
            case .escape: 53
            }
        }
    }

    private func post(_ key: Key, how: String) {
        if how == "ns" {
            let window = NSApp.windows.first {
                $0.isVisible && ($0.className.contains("Menu") || $0 is ProtoPanel)
            } ?? NSApp.keyWindow
            let characters: String = switch key {
            case let .text(text, _): text
            case .enter: "\r"
            case .escape: "\u{1b}"
            case .down: String(UnicodeScalar(NSDownArrowFunctionKey)!)
            case .up: String(UnicodeScalar(NSUpArrowFunctionKey)!)
            }
            for type in [NSEvent.EventType.keyDown, .keyUp] {
                if let event = NSEvent.keyEvent(with: type, location: .zero, modifierFlags: [],
                                                timestamp: ProcessInfo.processInfo.systemUptime,
                                                windowNumber: window?.windowNumber ?? 0, context: nil,
                                                characters: characters, charactersIgnoringModifiers: characters,
                                                isARepeat: false, keyCode: key.code) {
                    NSApp.postEvent(event, atStart: false)
                }
            }
        } else {
            for down in [true, false] {
                CGEvent(keyboardEventSource: nil, virtualKey: key.code, keyDown: down)?.postToPid(getpid())
            }
        }
        NSLog("[proto] selftest: posted %@ via %@", String(describing: key), how)
    }

    private enum Step {
        case key(Key), log(String), open, warpAway, warpBack, backspace, shot(String), click(Double)
    }

    private func selfTest() {
        let how = environment["PROTO_POST"] ?? "ns"
        let variant = ProtoState.shared.menuVariant
        let e = Step.key(.text("e", 14)), x = Step.key(.text("x", 7)), a = Step.key(.text("a", 0))
        let m = Step.key(.text("m", 46)), esc = Step.key(.escape), enter = Step.key(.enter)
        let script: [(Double, Step)] = [
            // phase 1: fresh menu, type, Enter without arrows
            (0.6, .log("P1 opened")), (0.2, e), (0.3, x), (0.5, .log("P1 typed ex")), (0.2, .shot("\(variant)-typed")),
            (0.6, enter), (0.8, .log("P1 Enter without arrows")), (0.2, esc), (0.2, esc),
            // phase 2: arrows, then typing and backspace after arrows, then Enter
            (0.5, .open), (1.0, e), (0.3, x), (0.3, .key(.down)), (0.3, .key(.down)), (0.4, .log("P2 ex ↓↓")),
            (0.3, a), (0.4, .log("P2 typed a after arrows")), (0.3, .backspace), (0.4, .log("P2 backspace")),
            (0.3, .key(.up)), (0.4, .log("P2 ↑")), (0.3, enter), (0.8, .log("P2 Enter")), (0.2, esc), (0.2, esc),
            // phase 3: rows appear and disappear
            (0.5, .open), (1.0, m), (0.3, a), (0.5, .log("P3 typed ma")), (0.3, .backspace), (0.3, .backspace),
            (0.6, .log("P3 emptied")), (0.3, esc), (0.6, .log("P3 Esc")), (0.2, esc), (0.5, .log("P3 second Esc")),
            // phase 4: menu bar while the cursor leaves it
            (0.5, .open), (1.0, e), (0.3, x), (0.4, .shot("\(variant)-bar-near")), (0.3, .warpAway),
            (2.5, .shot("\(variant)-bar-away")), (0.2, .log("P4 cursor away")), (0.1, .warpBack), (0.3, esc),
            (0.3, esc),
            // phase 5: a mouse click on the third row, then reopen to see the placeholder
            (0.5, .open), (1.0, e), (0.3, x), (0.5, .click(104)), (0.8, .log("P5 clicked row 3")), (0.2, esc),
            (0.5, .open), (1.2, .shot("\(variant)-reopened")), (0.2, .log("P5 reopened")), (0.3, esc), (0.2, esc),
        ]
        var delay = 0.0
        var saved = CGPoint.zero
        for (wait, step) in script {
            delay += wait
            after(delay) {
                switch step {
                case let .key(key): self.post(key, how: how)
                case .backspace: self.post(.text("\u{7f}", 51), how: how)
                case let .log(label): self.report(label)
                case .open: self.app?.openMenuSoon()
                case let .shot(name): Self.shoot(name)
                case .warpAway:
                    saved = CGEvent(source: nil)?.location ?? .zero
                    let screen = NSScreen.main?.frame ?? .zero
                    CGWarpMouseCursorPosition(CGPoint(x: screen.midX - 300, y: screen.midY + 250))
                    NSLog("[proto] warped from %@", NSStringFromPoint(saved))
                case .warpBack: CGWarpMouseCursorPosition(saved)
                case let .click(fromTop): self.click(fromTop: fromTop)
                }
            }
        }
        after(delay + 0.5) { NSLog("[proto] selftest: done") }
    }

    /// Posts a mouse down/up into the open menu window, `fromTop` points below its top edge.
    private func click(fromTop: Double) {
        guard let window = NSApp.windows.first(where: {
            $0.isVisible && ($0.className.contains("Menu") || $0 is ProtoPanel)
        }) else { return }
        let point = NSPoint(x: 150, y: window.frame.height - fromTop)
        let screenHeight = NSScreen.screens.first?.frame.height ?? 0
        let saved = CGEvent(source: nil)?.location ?? .zero
        CGWarpMouseCursorPosition(CGPoint(x: window.frame.minX + point.x, y: screenHeight - window.frame.minY - point.y))
        after(0.6) { CGWarpMouseCursorPosition(saved) }
        for type in [NSEvent.EventType.mouseMoved, .leftMouseDown, .leftMouseUp] {
            if let event = NSEvent.mouseEvent(with: type, location: point, modifierFlags: [],
                                              timestamp: ProcessInfo.processInfo.systemUptime,
                                              windowNumber: window.windowNumber, context: nil, eventNumber: 0,
                                              clickCount: 1, pressure: 1) {
                after(type == .mouseMoved ? 0.15 : type == .leftMouseDown ? 0.3 : 0.4) { NSApp.postEvent(event, atStart: false) }
            }
        }
        NSLog("[proto] selftest: posted click at %@ in %@", NSStringFromPoint(point), window.className)
    }

    /// Full-screen capture into /tmp only (never committed): used to see whether the menu bar is shown.
    private static func shoot(_ name: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-x", "/tmp/proto-selftest-\(name).png"]
        try? process.run()
    }

    private func report(_ label: String) {
        let menuWindows = NSApp.windows.filter { $0.isVisible && !$0.className.contains("StatusBar") }
            .map { "\($0.className) \(NSStringFromRect($0.frame)) key=\($0.isKeyWindow)" }
        let bar = NSApp.windows.first { $0.className.contains("StatusBar") }.map { NSStringFromRect($0.frame) } ?? "?"
        NSLog("[proto] selftest %@: menu bar visible=%@ status bar window=%@", label,
              NSMenu.menuBarVisible() ? "yes" : "no", bar)
        let state = ProtoState.shared
        NSLog("[proto] selftest %@: windows=%@ field=\"%@\" active=\"%@\" last=%@", label,
              menuWindows.joined(separator: ","), state.query, state.activeItem?.firstLine ?? "none", state.lastEvent)
    }
}

extension ProtoAppDelegate {
    /// Opens the menu from a timer, so the caller (a hook) is not blocked by menu tracking.
    func openMenuSoon() {
        ProtoHooks.shared.after(0.3) { self.openMenu(query: nil) }
    }
}
