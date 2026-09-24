// Acceptance-suite helper (issue #29). Never prints clipboard contents — only change counts and digests.
//   clipboard-vault save <file>     all items, all types, byte for byte (file 0600)
//   clipboard-vault restore <file>  writes them back
//   clipboard-vault digest          changeCount + SHA-256 over every item/type/bytes
//   clipboard-vault digest <file>   the same digest for a saved file
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

func digest(_ items: Items) -> String {
    var hash = SHA256()
    for item in items {
        hash.update(data: Data("item".utf8))
        for key in item.keys.sorted() {
            hash.update(data: Data(key.utf8))
            hash.update(data: item[key]!)
        }
    }
    return hash.finalize().map { String(format: "%02x", $0) }.joined()
}

let arguments = CommandLine.arguments
switch (arguments.count > 1 ? arguments[1] : "", arguments.count > 2 ? arguments[2] : nil) {
case ("save", let path?):
    let data = try PropertyListEncoder().encode(current())
    FileManager.default.createFile(atPath: path, contents: data, attributes: [.posixPermissions: 0o600])
    print("saved items=\(current().count) sha256=\(digest(current()))")
case ("restore", let path?):
    let items = try PropertyListDecoder().decode(Items.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    let written = items.map { types -> NSPasteboardItem in
        let item = NSPasteboardItem()
        for (type, data) in types { item.setData(data, forType: NSPasteboard.PasteboardType(type)) }
        return item
    }
    _ = pasteboard.writeObjects(written)
    print("restored items=\(items.count) sha256=\(digest(current())) matches=\(digest(current()) == digest(items))")
case ("digest", let path?):
    let items = try PropertyListDecoder().decode(Items.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
    print("file items=\(items.count) sha256=\(digest(items))")
case ("digest", nil):
    print("changeCount=\(NSPasteboard.general.changeCount) items=\(current().count) sha256=\(digest(current()))")
default:
    print("usage: clipboard-vault save|restore <file> | digest [file]")
    exit(2)
}
