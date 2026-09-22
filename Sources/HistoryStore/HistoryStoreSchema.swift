/// The history file's tables, versioned through `PRAGMA user_version` so later migrations have a starting point.
enum HistoryStoreSchema {
    static let currentVersion = 1

    /// Creates the schema in a new file, accepts the current version, and refuses any other. Turns on
    /// `secure_delete` so deleted, evicted and cleared text is overwritten in the file, not just unlinked.
    static func prepare(_ connection: SQLiteConnection) throws(HistoryStoreFailure) {
        try connection.run("PRAGMA secure_delete = ON", operation: "secureDelete")
        let version = try connection.integer("PRAGMA user_version", operation: "readSchemaVersion")
        switch version {
        case 0:
            try connection.inTransaction(operation: "createSchema") { () throws(HistoryStoreFailure) in
                try connection.run(createItemTable, operation: "createSchema")
                try connection.run(createCopySequenceIndex, operation: "createSchema")
                try connection.run("PRAGMA user_version = \(currentVersion)", operation: "createSchema")
            }
        case currentVersion:
            return
        default:
            throw .unsupportedSchemaVersion(version)
        }
    }

    /// `distinct_key`: see `DistinctKey`. `text`: the latest copy's exact text. `copy_sequence`: strictly
    /// increasing, the newest copy has the largest; ordering never depends on the wall clock.
    private static let createItemTable = """
        CREATE TABLE clipboard_item (
            distinct_key BLOB PRIMARY KEY,
            text TEXT NOT NULL,
            copy_sequence INTEGER NOT NULL
        )
        """

    private static let createCopySequenceIndex =
        "CREATE INDEX clipboard_item_by_copy_sequence ON clipboard_item (copy_sequence)"
}
