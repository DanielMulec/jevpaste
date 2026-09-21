import AppKit

// THROWAWAY probe for github.com/DanielMulec/jevpaste issue #11.
// Never logs clipboard or field contents — lengths, types, hashes and timings only.
//
// Commands arrive either on stdin (when the binary is run directly from a terminal) or on a
// FIFO given by `--fifo`. The FIFO path exists so the bundle can be launched via LaunchServices
// (`open -n MacOSProbe.app --args --fifo …`), which makes the app its own responsible process
// for TCC instead of inheriting the terminal's identity.

final class ProbeDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Indicator.installStatusItem()
        Env.report()
        Log.line("ready — type `help`. Cmd+Shift+V runs the armed battery once a hotkey is enabled.")
    }
}

func argument(_ name: String) -> String? {
    let args = CommandLine.arguments
    guard let index = args.firstIndex(of: name), index + 1 < args.count else { return nil }
    return args[index + 1]
}

let transcriptPath = argument("--log")
    ?? ProcessInfo.processInfo.environment["PROBE_LOG"]
    ?? FileManager.default.currentDirectoryPath + "/probe-transcript.log"
Log.openTranscript(transcriptPath)

let app = NSApplication.shared
let delegate = ProbeDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)

func dispatch(_ raw: String) {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    // Every command runs on the main thread: AppKit, Carbon and the Accessibility API expect it.
    DispatchQueue.main.async { Commands.shared.run(trimmed) }
}

let commandThread = Thread {
    if let fifo = argument("--fifo") {
        Log.line("reading commands from FIFO \(fifo)")
        var buffer = Data()
        while true {
            guard let handle = FileHandle(forReadingAtPath: fifo) else {
                Thread.sleep(forTimeInterval: 0.5)
                continue
            }
            while true {
                let chunk = handle.availableData
                if chunk.isEmpty { break }
                buffer.append(chunk)
                while let newline = buffer.firstIndex(of: 0x0A) {
                    let lineData = Data(buffer[buffer.startIndex..<newline])
                    buffer = Data(buffer[buffer.index(after: newline)...])
                    dispatch(String(data: lineData, encoding: .utf8) ?? "")
                }
            }
            try? handle.close()
        }
    } else {
        while let line = readLine(strippingNewline: true) { dispatch(line) }
        Log.line("stdin closed — probe stays alive; use `quit` or Ctrl-C to exit")
    }
}
commandThread.start()

app.run()
