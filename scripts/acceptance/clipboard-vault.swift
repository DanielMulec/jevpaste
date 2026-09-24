// Acceptance-suite helper (issue #29). Never prints clipboard contents — only change counts and digests.
//   clipboard-vault save <file>     all items, all types, byte for byte (file 0600)
//   clipboard-vault restore <file>  writes them back
//   clipboard-vault digest          changeCount + SHA-256 over every item/type/bytes (length-framed)
//   clipboard-vault digest <file>   the same digest for a saved file
//   clipboard-vault selftest        framing check: inputs the old unframed digest confused hash apart
import AppKit
import CryptoKit

typealias Items = [[String: Data]]

func current() -> Items {
    (NSPasteboard.general.pasteboardItems ?? []).map { item in
        var types: [String: Data] = [:]
        for type in item.types { if let data = item.data(forType: type) { types[type.rawValue] = data } }
        return types
    }
}

/// SHA-256 over an unambiguous framing: a version tag, the item count, and per item its type count and every
/// (type name, bytes) pair, each preceded by its byte length. Two different pasteboards can never frame alike.
func digest(_ items: Items) -> String {
    var hash = SHA256()
    func frame(_ count: Int) { withUnsafeBytes(of: UInt64(count).bigEndian) { hash.update(bufferPointer: $0) } }
    func frame(_ data: Data) { frame(data.count); hash.update(data: data) }
    frame(Data("clipboard-vault/2".utf8))
    frame(items.count)
    for item in items {
        frame(item.count)
        for key in item.keys.sorted() {
            frame(Data(key.utf8))
            frame(item[key]!)
        }
    }
    return hash.finalize().map { String(format: "%02x", $0) }.joined()
}

func load(_ path: String) throws -> Items {
    try PropertyListDecoder().decode(Items.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
}

let arguments = CommandLine.arguments
switch (arguments.count > 1 ? arguments[1] : "", arguments.count > 2 ? arguments[2] : nil) {
case ("save", let path?):
    let snapshot = current()
    let data = try PropertyListEncoder().encode(snapshot)
    guard FileManager.default.createFile(atPath: path, contents: data, attributes: [.posixPermissions: 0o600])
    else { print("save failed"); exit(1) }
    // Digest what is on disk, not a second read of the pasteboard.
    let saved = try load(path)
    guard digest(saved) == digest(snapshot) else { print("save mismatch"); exit(1) }
    print("saved items=\(saved.count) sha256=\(digest(saved))")
case ("restore", let path?):
    let items = try load(path)
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    let written = items.map { types -> NSPasteboardItem in
        let item = NSPasteboardItem()
        for (type, data) in types { item.setData(data, forType: NSPasteboard.PasteboardType(type)) }
        return item
    }
    guard pasteboard.writeObjects(written) else { print("restore failed"); exit(1) }
    let now = digest(current())
    print("restored items=\(items.count) sha256=\(now) matches=\(now == digest(items))")
    if now != digest(items) { exit(1) }
case ("digest", let path?):
    let items = try load(path)
    print("file items=\(items.count) sha256=\(digest(items))")
case ("digest", nil):
    let changeCount = NSPasteboard.general.changeCount
    let items = current()
    guard NSPasteboard.general.changeCount == changeCount else { print("clipboard changed while reading"); exit(1) }
    print("changeCount=\(changeCount) items=\(items.count) sha256=\(digest(items))")
case ("selftest", nil):
    // Regression cases: each pair hashed alike under the unframed digest of 9f30b18 (checked below with
    // `unframedDigest`), and must hash apart under the framed one. Boundaries: type/bytes, item, type count.
    func unframedDigest(_ items: Items) -> String {
        var hash = SHA256()
        for item in items {
            hash.update(data: Data("item".utf8))
            for key in item.keys.sorted() { hash.update(data: Data(key.utf8)); hash.update(data: item[key]!) }
        }
        return hash.finalize().map { String(format: "%02x", $0) }.joined()
    }
    let pairs: [(Items, Items)] = [
        ([["a": Data("bc".utf8)]], [["ab": Data("c".utf8)]]),
        ([["a": Data("itemb".utf8)]], [["a": Data()], ["b": Data()]]),
        ([["a": Data("b".utf8), "c": Data()]], [["a": Data("bc".utf8)]]),
    ]
    let oldCollided = pairs.filter { unframedDigest($0.0) == unframedDigest($0.1) }.count
    let framedDistinct = pairs.filter { digest($0.0) != digest($0.1) }.count
    print("selftest oldCollided=\(oldCollided)/\(pairs.count) framedDistinct=\(framedDistinct)/\(pairs.count)")
    if oldCollided != pairs.count || framedDistinct != pairs.count { exit(1) }
default:
    print("usage: clipboard-vault save|restore <file> | digest [file]")
    exit(2)
}
