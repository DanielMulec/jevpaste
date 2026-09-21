import AppKit
import ApplicationServices
import Carbon.HIToolbox

/// Command interpreter. The probe is driven from stdin so one launch (= one TCC grant) can run
/// every experiment; `arm` + the global hotkey drives the tests that need another app focused.
final class Commands {
    static let shared = Commands()
    private let watcher = ClipboardWatcher()

    func run(_ line: String) {
        let parts = line.split(separator: " ").map(String.init)
        guard let verb = parts.first else { return }
        let args = Array(parts.dropFirst())
        func number(_ index: Int, _ fallback: Double) -> Double {
            index < args.count ? (Double(args[index]) ?? fallback) : fallback
        }

        Log.line("> \(line)")
        switch verb {
        case "help": help()
        case "env": Env.report()
        case "perm": Env.permissions()
        case "ask-ax": Env.requestAccessibility()
        case "ask-post": Env.requestPostEvent()
        case "ask-listen": Env.requestListenEvent()
        case "ladder": Env.accessLadder()
        case "detectvalues": Env.detectValues()
        case "watch": watcher.start(intervalMs: number(0, 200), readContent: args.contains("read"))
        case "unwatch": watcher.stop()
        case "hk": hotkey(args.first ?? "status")
        case "arm": arm(args.first ?? "none")
        case "id": AXProbe.identify()
        case "ctx": ContextProbe.harvest()
        case "timings": Env.axTimings(iterations: Int(number(0, 10)))
        case "paste": Insertion.pasteSwap(restoreDelayMs: number(0, 120))
        case "axinsert": Insertion.axInsert()
        case "race": Insertion.raceTest(windowMs: number(0, 300))
        case "drift": Insertion.focusDrift(delayMs: number(0, 800))
        case "wake": wake(args.first ?? "AXEnhancedUserInterface")
        case "ind": indicator(args.first ?? "status")
        case "after": after(args)
        case "copytest": copyTest(count: Int(number(0, 5)))
        case "note": Log.line("NOTE \(args.joined(separator: " "))")
        case "quit": Log.line("bye"); exit(0)
        default: Log.line("unknown command: \(verb) — try `help`")
        }
    }

    private func help() {
        let text = """
        env | perm | ask-ax | ask-post | ask-listen
        ladder                     access ladder: changeCount -> types -> detectPatterns -> content read
        detectvalues               detectedValues (documented to notify)
        watch <ms> [read]          changeCount poller; add `read` to also read content
        unwatch
        hk carbon|tap|monitor|off|status
        arm identify|full|paste|axinsert|drift|none      what Cmd+Shift+V runs
        id                         identify the focused target right now
        ctx                        harvest bounded surrounding context (counts + timings only)
        timings <n>                AX read percentiles
        paste <restoreDelayMs>     insertion A: swap + synthesized Cmd+V + restore
        axinsert                   insertion B: AXSelectedText then AXValue
        race <windowMs>            concurrent copy during the swap window
        drift <ms>                 focus drift over a simulated round trip
        wake AXEnhancedUserInterface|AXManualAccessibility
        ind status|panel|alert|notify|notify-auth
        after <seconds> <command>  run a command after N seconds (focus the target meanwhile)
        note <text>                write a marker into the transcript
        quit
        """
        text.split(separator: "\n").forEach { Log.line(String($0)) }
    }

    private func hotkey(_ which: String) {
        switch which {
        case "carbon": Log.line("HK carbon \(HotkeyProbe.shared.enableCarbon())")
        case "tap": Log.line("HK eventTap \(HotkeyProbe.shared.enableEventTap())")
        case "monitor": Log.line("HK globalMonitor \(HotkeyProbe.shared.enableGlobalMonitor())")
        case "off":
            HotkeyProbe.shared.disableCarbon()
            HotkeyProbe.shared.disableEventTap()
            HotkeyProbe.shared.disableGlobalMonitor()
            Log.line("HK all disabled")
        default: Log.line("HK status \(HotkeyProbe.shared.status)")
        }
    }

    private func arm(_ name: String) {
        switch name {
        case "identify":
            HotkeyProbe.shared.armedAction = { AXProbe.identify(label: "AX@hotkey") }
        case "full":
            HotkeyProbe.shared.armedAction = { Commands.fullBattery() }
        case "paste":
            HotkeyProbe.shared.armedAction = { Insertion.pasteSwap(restoreDelayMs: 120) }
        case "axinsert":
            HotkeyProbe.shared.armedAction = { Insertion.axInsert() }
        case "drift":
            HotkeyProbe.shared.armedAction = { Insertion.focusDrift(delayMs: 800) }
        case "none":
            HotkeyProbe.shared.armedAction = nil
        default:
            Log.line("unknown battery: \(name)")
            return
        }
        Log.line("ARM \(name)")
    }

    /// One hotkey press produces the whole per-target row of the results matrix.
    static func fullBattery() {
        Log.line("===== BATTERY begin =====")
        let focus = AXProbe.identify(label: "AX@hotkey")
        ContextProbe.harvest(label: "CTX@hotkey")
        Env.axTimings(iterations: 5)
        if focus.element != nil {
            let secureNow = IsSecureEventInputEnabled()
            if secureNow {
                Log.fail("BATTERY secure event input is ON — refusing insertion into this target")
                Indicator.flashStatus("blocked")
                Indicator.flashPanel("jevpaste: secure target — nothing inserted")
            } else {
                Insertion.pasteSwap(restoreDelayMs: 120)
            }
        } else {
            Indicator.flashStatus("no-target")
            Indicator.flashPanel("jevpaste: target not readable")
        }
        Log.line("===== BATTERY end =====")
    }

    private func wake(_ attribute: String) {
        guard let front = NSWorkspace.shared.frontmostApplication else { return }
        Log.line("WAKE target=\(front.bundleIdentifier ?? "nil") pid=\(front.processIdentifier)")
        Log.line("WAKE before: (identify)")
        AXProbe.identify(label: "AX-before-wake")
        Log.line("WAKE \(AXProbe.wake(pid: front.processIdentifier, attribute: attribute))")
        Thread.sleep(forTimeInterval: 0.4)
        AXProbe.identify(label: "AX-after-wake")
    }

    private func indicator(_ kind: String) {
        switch kind {
        case "status": Indicator.flashStatus("FAIL")
        case "panel": Indicator.flashPanel("jevpaste: no suitable match")
        case "alert": Indicator.modalAlert("Simulated failure state (auto-dismiss in 2s)")
        case "notify": Indicator.postNotification("Simulated failure state")
        case "notify-auth": Indicator.requestNotificationAuthorization()
        default: Log.line("unknown indicator: \(kind)")
        }
    }

    /// Writes synthetic items on a background queue and lets the watcher measure detection latency.
    private func copyTest(count: Int) {
        Log.line("COPYTEST writing \(count) synthetic items, 1s apart")
        for index in 0..<count {
            DispatchQueue.global().asyncAfter(deadline: .now() + Double(index) * 1.0) {
                Clipboard.markedWriteAt = DispatchTime.now().uptimeNanoseconds
                let item = NSPasteboardItem()
                item.setString("JEVPROBE-COPYTEST-\(index)", forType: .string)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.writeObjects([item])
            }
        }
    }

    private func after(_ args: [String]) {
        guard let seconds = Double(args.first ?? ""), args.count > 1 else {
            Log.line("usage: after <seconds> <command...>")
            return
        }
        let rest = args.dropFirst().joined(separator: " ")
        Log.line("AFTER scheduling `\(rest)` in \(seconds)s — focus the target now")
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak self] in
            self?.run(rest)
        }
    }
}
