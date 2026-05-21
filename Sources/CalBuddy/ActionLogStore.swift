import Foundation
import SQLite3

enum ActionType: String, Codable, Sendable {
    case createEvent
    case updateEvent
    case deleteEvent
    case revertAction
}

enum ActionStatus: String, Codable, Sendable {
    case succeeded
}

enum InverseOperationKind: String, Codable, Sendable {
    case deleteEvent
    case restoreEvent
    case recreateEvent
}

struct ActionInverseOperation: Codable, Equatable, Sendable {
    var kind: InverseOperationKind
    var targetIdentifier: String?
    var snapshot: CalendarEventSnapshot?
}

struct ActionLogEntry: Codable, Equatable, Sendable {
    static let schemaVersion = 1

    var actionID: String
    var timestamp: Date
    var schemaVersion: Int
    var actionType: ActionType
    var status: ActionStatus
    var actor: String?
    var source: String?
    var commandLine: [String]
    var targetIdentifiers: [String]
    var beforeSnapshot: CalendarEventSnapshot?
    var afterSnapshot: CalendarEventSnapshot?
    var inverseOperation: ActionInverseOperation
    var errorDetails: String?
    var forced: Bool
    var revertedActionID: String?
}

final class ActionLogStore {
    private let path: String
    private var db: OpaquePointer?

    init(path: String) {
        self.path = (path as NSString).expandingTildeInPath
    }

    deinit {
        if let db {
            sqlite3_close(db)
        }
    }

    static func defaultDatabasePath(
        homeDirectory: String = FileManager.default.homeDirectoryForCurrentUser.path
    ) -> String {
        (homeDirectory as NSString)
            .appendingPathComponent("Library/Application Support/calbuddy/action-log.sqlite3")
    }

    static func resolveDatabasePath(
        override: String?,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectory: String = FileManager.default.homeDirectoryForCurrentUser.path
    ) -> String {
        if let override, !override.isEmpty {
            return (override as NSString).expandingTildeInPath
        }
        if let envPath = environment["CALBUDDY_ACTION_LOG_DB"], !envPath.isEmpty {
            return (envPath as NSString).expandingTildeInPath
        }
        return defaultDatabasePath(homeDirectory: homeDirectory)
    }

    func ensureReady() throws {
        try openIfNeeded()
        try execute("""
            CREATE TABLE IF NOT EXISTS schema_migrations (
                key TEXT PRIMARY KEY NOT NULL,
                value INTEGER NOT NULL
            );
            """)
        try execute("""
            CREATE TABLE IF NOT EXISTS action_log (
                action_id TEXT PRIMARY KEY NOT NULL,
                timestamp TEXT NOT NULL,
                schema_version INTEGER NOT NULL,
                action_type TEXT NOT NULL,
                status TEXT NOT NULL,
                actor TEXT,
                source TEXT,
                command_line_json TEXT NOT NULL,
                target_identifiers_json TEXT NOT NULL,
                before_json TEXT,
                after_json TEXT,
                inverse_json TEXT NOT NULL,
                error_details TEXT,
                forced INTEGER NOT NULL DEFAULT 0,
                reverted_action_id TEXT
            );
            """)
        try execute("""
            CREATE TRIGGER IF NOT EXISTS prevent_action_log_update
            BEFORE UPDATE ON action_log
            BEGIN
                SELECT RAISE(ABORT, 'action_log is append-only');
            END;
            """)
        try execute("""
            CREATE TRIGGER IF NOT EXISTS prevent_action_log_delete
            BEFORE DELETE ON action_log
            BEGIN
                SELECT RAISE(ABORT, 'action_log is append-only');
            END;
            """)
        try execute("""
            INSERT OR IGNORE INTO schema_migrations (key, value)
            VALUES ('action_log_schema', 1);
            """)
    }

    func append(_ entry: ActionLogEntry) throws {
        try ensureReady()
        let sql = """
            INSERT INTO action_log (
                action_id, timestamp, schema_version, action_type, status,
                actor, source, command_line_json, target_identifiers_json,
                before_json, after_json, inverse_json, error_details, forced,
                reverted_action_id
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """
        try withStatement(sql) { statement in
            try bindText(entry.actionID, to: statement, at: 1)
            try bindText(Self.iso8601String(entry.timestamp), to: statement, at: 2)
            sqlite3_bind_int(statement, 3, Int32(entry.schemaVersion))
            try bindText(entry.actionType.rawValue, to: statement, at: 4)
            try bindText(entry.status.rawValue, to: statement, at: 5)
            try bindNullableText(entry.actor, to: statement, at: 6)
            try bindNullableText(entry.source, to: statement, at: 7)
            try bindText(Self.encodeJSON(entry.commandLine), to: statement, at: 8)
            try bindText(Self.encodeJSON(entry.targetIdentifiers), to: statement, at: 9)
            try bindNullableText(Self.encodeOptionalJSON(entry.beforeSnapshot), to: statement, at: 10)
            try bindNullableText(Self.encodeOptionalJSON(entry.afterSnapshot), to: statement, at: 11)
            try bindText(Self.encodeJSON(entry.inverseOperation), to: statement, at: 12)
            try bindNullableText(entry.errorDetails, to: statement, at: 13)
            sqlite3_bind_int(statement, 14, entry.forced ? 1 : 0)
            try bindNullableText(entry.revertedActionID, to: statement, at: 15)
            try stepDone(statement)
        }
    }

    func list(limit: Int) throws -> [ActionLogEntry] {
        try ensureReady()
        let safeLimit = max(1, limit)
        return try query("""
            SELECT action_id, timestamp, schema_version, action_type, status,
                   actor, source, command_line_json, target_identifiers_json,
                   before_json, after_json, inverse_json, error_details, forced,
                   reverted_action_id
            FROM action_log
            ORDER BY timestamp DESC
            LIMIT ?;
            """) { statement in
            sqlite3_bind_int(statement, 1, Int32(safeLimit))
        }
    }

    func get(actionID: String) throws -> ActionLogEntry? {
        try ensureReady()
        let entries = try query("""
            SELECT action_id, timestamp, schema_version, action_type, status,
                   actor, source, command_line_json, target_identifiers_json,
                   before_json, after_json, inverse_json, error_details, forced,
                   reverted_action_id
            FROM action_log
            WHERE action_id = ?;
            """) { statement in
            try bindText(actionID, to: statement, at: 1)
        }
        return entries.first
    }

    private func openIfNeeded() throws {
        guard db == nil else { return }
        let directory = (path as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(
            atPath: directory,
            withIntermediateDirectories: true
        )
        guard sqlite3_open(path, &db) == SQLITE_OK else {
            let message = db.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown SQLite error"
            throw CalendarActionError.logFailure("Could not open action log database: \(message)")
        }
    }

    private func execute(_ sql: String) throws {
        try openIfNeeded()
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
            throw CalendarActionError.logFailure(sqliteErrorMessage())
        }
    }

    private func withStatement(_ sql: String, _ body: (OpaquePointer?) throws -> Void) throws {
        try openIfNeeded()
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw CalendarActionError.logFailure(sqliteErrorMessage())
        }
        defer { sqlite3_finalize(statement) }
        try body(statement)
    }

    private func query(_ sql: String, bind: (OpaquePointer?) throws -> Void) throws -> [ActionLogEntry] {
        try openIfNeeded()
        var rows: [ActionLogEntry] = []
        try withStatement(sql) { statement in
            try bind(statement)
            while true {
                let result = sqlite3_step(statement)
                if result == SQLITE_ROW {
                    rows.append(try decodeRow(statement))
                } else if result == SQLITE_DONE {
                    break
                } else {
                    throw CalendarActionError.logFailure(sqliteErrorMessage())
                }
            }
        }
        return rows
    }

    private func decodeRow(_ statement: OpaquePointer?) throws -> ActionLogEntry {
        let actionID = columnText(statement, 0) ?? ""
        let timestampText = columnText(statement, 1) ?? ""
        let timestamp = Self.iso8601Date(timestampText) ?? Date(timeIntervalSince1970: 0)
        let schemaVersion = Int(sqlite3_column_int(statement, 2))
        let actionType = ActionType(rawValue: columnText(statement, 3) ?? "") ?? .createEvent
        let status = ActionStatus(rawValue: columnText(statement, 4) ?? "") ?? .succeeded
        let commandLine: [String] = try Self.decodeJSON(columnText(statement, 7) ?? "[]")
        let targetIdentifiers: [String] = try Self.decodeJSON(columnText(statement, 8) ?? "[]")
        let beforeSnapshot: CalendarEventSnapshot? = try Self.decodeOptionalJSON(columnText(statement, 9))
        let afterSnapshot: CalendarEventSnapshot? = try Self.decodeOptionalJSON(columnText(statement, 10))
        let inverseOperation: ActionInverseOperation = try Self.decodeJSON(columnText(statement, 11) ?? "{}")

        return ActionLogEntry(
            actionID: actionID,
            timestamp: timestamp,
            schemaVersion: schemaVersion,
            actionType: actionType,
            status: status,
            actor: columnText(statement, 5),
            source: columnText(statement, 6),
            commandLine: commandLine,
            targetIdentifiers: targetIdentifiers,
            beforeSnapshot: beforeSnapshot,
            afterSnapshot: afterSnapshot,
            inverseOperation: inverseOperation,
            errorDetails: columnText(statement, 12),
            forced: sqlite3_column_int(statement, 13) != 0,
            revertedActionID: columnText(statement, 14)
        )
    }

    private func sqliteErrorMessage() -> String {
        db.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown SQLite error"
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(iso8601String(date))
        }
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            guard let date = iso8601Date(raw) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Invalid ISO8601 date: \(raw)"
                )
            }
            return date
        }
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }

    static func encodeJSON<T: Encodable>(_ value: T) throws -> String {
        let data = try makeEncoder().encode(value)
        return String(decoding: data, as: UTF8.self)
    }

    static func encodeOptionalJSON<T: Encodable>(_ value: T?) throws -> String? {
        guard let value else { return nil }
        return try encodeJSON(value)
    }

    static func decodeJSON<T: Decodable>(_ raw: String) throws -> T {
        try makeDecoder().decode(T.self, from: Data(raw.utf8))
    }

    static func decodeOptionalJSON<T: Decodable>(_ raw: String?) throws -> T? {
        guard let raw else { return nil }
        return try decodeJSON(raw)
    }

    static func iso8601String(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }

    static func iso8601Date(_ raw: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: raw) {
            return date
        }
        return ISO8601DateFormatter().date(from: raw)
    }
}

private func bindText(_ value: String, to statement: OpaquePointer?, at index: Int32) throws {
    guard sqlite3_bind_text(statement, index, value, -1, SQLITE_TRANSIENT) == SQLITE_OK else {
        throw CalendarActionError.logFailure("Could not bind SQLite text value")
    }
}

private func bindNullableText(_ value: String?, to statement: OpaquePointer?, at index: Int32) throws {
    guard let value else {
        sqlite3_bind_null(statement, index)
        return
    }
    try bindText(value, to: statement, at: index)
}

private func stepDone(_ statement: OpaquePointer?) throws {
    guard sqlite3_step(statement) == SQLITE_DONE else {
        throw CalendarActionError.logFailure("SQLite statement failed")
    }
}

private func columnText(_ statement: OpaquePointer?, _ index: Int32) -> String? {
    guard sqlite3_column_type(statement, index) != SQLITE_NULL,
          let text = sqlite3_column_text(statement, index)
    else {
        return nil
    }
    return String(cString: text)
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
