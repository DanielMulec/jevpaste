import Foundation
import CryptoKit

/// Logging for the probe. SAFETY RULE: this probe never logs clipboard or field payloads.
/// Only lengths, type identifiers, hashes and counts. `Log.synthetic` is the single exception
/// and may only be used for strings the probe itself created.
enum Log {
    private static let start = Date()
    private static var handle: FileHandle?
    private static let queue = DispatchQueue(label: "probe.log")

    static func openTranscript(_ path: String) {
        FileManager.default.createFile(atPath: path, contents: nil)
        handle = FileHandle(forWritingAtPath: path)
        line("transcript opened at \(path)")
    }

    static func line(_ text: String) {
        let stamp = String(format: "%8.3f", Date().timeIntervalSince(start))
        let rendered = "[\(stamp)] \(text)"
        queue.sync {
            print(rendered)
            fflush(stdout)
            if let data = (rendered + "\n").data(using: .utf8) { handle?.write(data) }
        }
    }

    static func kv(_ label: String, _ pairs: [(String, String)]) {
        let body = pairs.map { "\($0.0)=\($0.1)" }.joined(separator: " ")
        line("\(label) \(body)")
    }

    /// Only for strings this probe generated itself.
    static func synthetic(_ text: String) { line("SYNTHETIC \(text)") }

    static func fail(_ text: String) { line("FAIL \(text)") }
}

enum Digest {
    /// Short hash so two payloads can be compared for equality without revealing them.
    static func short(_ data: Data) -> String {
        let sum = SHA256.hash(data: data)
        return sum.map { String(format: "%02x", $0) }.joined().prefix(12).description
    }

    static func short(_ text: String) -> String { short(Data(text.utf8)) }
}

enum Clock {
    /// Wall-clock milliseconds for `body`, rounded to two decimals.
    static func measure<T>(_ body: () -> T) -> (T, Double) {
        let began = DispatchTime.now().uptimeNanoseconds
        let value = body()
        let elapsed = Double(DispatchTime.now().uptimeNanoseconds - began) / 1_000_000.0
        return (value, (elapsed * 100).rounded() / 100)
    }

    static func percentiles(_ samples: [Double]) -> (p50: Double, p95: Double, max: Double) {
        guard !samples.isEmpty else { return (0, 0, 0) }
        let sorted = samples.sorted()
        func at(_ fraction: Double) -> Double {
            let index = min(sorted.count - 1, Int((fraction * Double(sorted.count)).rounded(.down)))
            return sorted[index]
        }
        return (at(0.5), at(0.95), sorted[sorted.count - 1])
    }
}
