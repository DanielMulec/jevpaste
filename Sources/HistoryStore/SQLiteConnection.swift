import Foundation
import SQLite3

/// A value bound to a `?NNN` parameter of a statement.
enum SQLiteValue {
    case integer(Int)
    case text(String)
    case blob(Data)
}

/// One open SQLite database: the only place in the module that calls the `SQLite3` C API.
///
/// Not thread-safe. Its owner confines it to one serial queue.
final class SQLiteConnection {
    private let handle: OpaquePointer

    /// Opens (creating if absent) the database file at `fileURL`.
    init(fileURL: URL) throws(HistoryStoreFailure) {
        var opened: OpaquePointer?
        let resultCode = sqlite3_open_v2(fileURL.path, &opened, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil)
        guard resultCode == SQLITE_OK, let opened else {
            sqlite3_close_v2(opened)
            throw .sqlite(operation: "open", resultCode: resultCode)
        }
        handle = opened
    }

    deinit {
        sqlite3_close_v2(handle)
    }

    /// Runs one statement to completion and returns the number of rows it changed.
    @discardableResult
    func run(_ sql: String, _ values: SQLiteValue..., operation: String) throws(HistoryStoreFailure) -> Int {
        let statement = try prepare(sql, values, operation: operation)
        defer { sqlite3_finalize(statement) }
        var resultCode = sqlite3_step(statement)
        while resultCode == SQLITE_ROW {
            resultCode = sqlite3_step(statement)
        }
        guard resultCode == SQLITE_DONE else { throw .sqlite(operation: operation, resultCode: resultCode) }
        return Int(sqlite3_changes(handle))
    }

    /// Runs one query and returns the text of its first column for every row; rows that are not valid UTF-8 (only
    /// possible if the file was edited outside this module) are skipped.
    func texts(_ sql: String, _ values: SQLiteValue..., operation: String) throws(HistoryStoreFailure) -> [String] {
        let statement = try prepare(sql, values, operation: operation)
        defer { sqlite3_finalize(statement) }
        var texts: [String] = []
        var resultCode = sqlite3_step(statement)
        while resultCode == SQLITE_ROW {
            if let text = Self.text(inFirstColumnOf: statement) {
                texts.append(text)
            }
            resultCode = sqlite3_step(statement)
        }
        guard resultCode == SQLITE_DONE else { throw .sqlite(operation: operation, resultCode: resultCode) }
        return texts
    }

    /// Runs one query that yields a single integer, such as `PRAGMA user_version`.
    func integer(_ sql: String, operation: String) throws(HistoryStoreFailure) -> Int {
        let statement = try prepare(sql, [], operation: operation)
        defer { sqlite3_finalize(statement) }
        let resultCode = sqlite3_step(statement)
        guard resultCode == SQLITE_ROW else { throw .sqlite(operation: operation, resultCode: resultCode) }
        return Int(sqlite3_column_int64(statement, 0))
    }

    /// Runs `body` inside one transaction: committed if it returns, rolled back if it throws.
    func inTransaction<Result>(
        operation: String,
        _ body: () throws(HistoryStoreFailure) -> Result
    ) throws(HistoryStoreFailure) -> Result {
        try run("BEGIN IMMEDIATE", operation: operation)
        do {
            let result = try body()
            try run("COMMIT", operation: operation)
            return result
        } catch {
            sqlite3_exec(handle, "ROLLBACK", nil, nil, nil)
            throw error
        }
    }

    private func prepare(
        _ sql: String,
        _ values: [SQLiteValue],
        operation: String
    ) throws(HistoryStoreFailure) -> OpaquePointer {
        var prepared: OpaquePointer?
        let resultCode = sqlite3_prepare_v2(handle, sql, -1, &prepared, nil)
        guard resultCode == SQLITE_OK, let prepared else {
            sqlite3_finalize(prepared)
            throw .sqlite(operation: operation, resultCode: resultCode)
        }
        for (offset, value) in values.enumerated() {
            let bindCode = Self.bind(value, at: Int32(offset + 1), in: prepared)
            guard bindCode == SQLITE_OK else {
                sqlite3_finalize(prepared)
                throw .sqlite(operation: operation, resultCode: bindCode)
            }
        }
        return prepared
    }

    /// Tells SQLite to copy bound bytes before the call returns (`SQLITE_TRANSIENT`).
    private static var copyBeforeReturning: sqlite3_destructor_type {
        unsafeBitCast(OpaquePointer(bitPattern: -1), to: sqlite3_destructor_type.self)
    }

    private static func bind(_ value: SQLiteValue, at index: Int32, in statement: OpaquePointer) -> Int32 {
        switch value {
        case .integer(let integer):
            return sqlite3_bind_int64(statement, index, Int64(integer))
        case .text(let text):
            let bytes = Array(text.utf8)
            return sqlite3_bind_text64(
                statement, index, bytes, UInt64(bytes.count), copyBeforeReturning, UInt8(SQLITE_UTF8))
        case .blob(let data):
            return data.withUnsafeBytes { buffer in
                sqlite3_bind_blob64(statement, index, buffer.baseAddress, UInt64(buffer.count), copyBeforeReturning)
            }
        }
    }

    /// The first column as text, byte for byte, including any embedded NUL characters; `nil` if not UTF-8.
    private static func text(inFirstColumnOf statement: OpaquePointer) -> String? {
        // SQLite's documented order: fetch the text first, then its byte count.
        guard let bytes = sqlite3_column_text(statement, 0) else { return nil }
        let byteCount = Int(sqlite3_column_bytes(statement, 0))
        return String(bytes: UnsafeBufferPointer(start: bytes, count: byteCount), encoding: .utf8)
    }
}
