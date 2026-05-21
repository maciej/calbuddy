import SQLite3
import XCTest
@testable import CalBuddy

final class ActionLogStoreTests: XCTestCase {
    func testAppendListAndShow() throws {
        let store = ActionLogStore(path: tempDatabasePath())
        let entry = sampleEntry(actionID: "action-1")

        try store.append(entry)

        let entries = try store.list(limit: 20)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].actionID, "action-1")
        XCTAssertEqual(entries[0].actionType, .createEvent)
        XCTAssertEqual(entries[0].afterSnapshot?.title, "Original")

        let shown = try store.get(actionID: "action-1")
        XCTAssertEqual(shown?.actionID, "action-1")
        XCTAssertEqual(shown?.inverseOperation.kind, .deleteEvent)
    }

    func testMigrationCreatesAppendOnlyTriggers() throws {
        let path = tempDatabasePath()
        let store = ActionLogStore(path: path)
        try store.append(sampleEntry(actionID: "action-1"))

        XCTAssertEqual(queryCount(path: path, table: "action_log"), 1)
        XCTAssertEqual(queryCount(path: path, table: "schema_migrations"), 1)

        XCTAssertNotEqual(rawExec(path: path, sql: "UPDATE action_log SET status = 'failed' WHERE action_id = 'action-1';"), SQLITE_OK)
        XCTAssertNotEqual(rawExec(path: path, sql: "DELETE FROM action_log WHERE action_id = 'action-1';"), SQLITE_OK)
        XCTAssertEqual(try store.list(limit: 20).count, 1)
    }

    func testDatabasePathPrecedence() {
        let resolvedOverride = ActionLogStore.resolveDatabasePath(
            override: "/tmp/override.sqlite3",
            environment: ["CALBUDDY_ACTION_LOG_DB": "/tmp/env.sqlite3"],
            homeDirectory: "/Users/example"
        )
        XCTAssertEqual(resolvedOverride, "/tmp/override.sqlite3")

        let resolvedEnv = ActionLogStore.resolveDatabasePath(
            override: nil,
            environment: ["CALBUDDY_ACTION_LOG_DB": "/tmp/env.sqlite3"],
            homeDirectory: "/Users/example"
        )
        XCTAssertEqual(resolvedEnv, "/tmp/env.sqlite3")

        let resolvedDefault = ActionLogStore.resolveDatabasePath(
            override: nil,
            environment: [:],
            homeDirectory: "/Users/example"
        )
        XCTAssertEqual(resolvedDefault, "/Users/example/Library/Application Support/calbuddy/action-log.sqlite3")
    }

    private func sampleEntry(actionID: String) -> ActionLogEntry {
        let snapshot = sampleSnapshot(id: "event-1", title: "Original")
        return ActionLogEntry(
            actionID: actionID,
            timestamp: Date(timeIntervalSince1970: 1_800_000_000),
            schemaVersion: ActionLogEntry.schemaVersion,
            actionType: .createEvent,
            status: .succeeded,
            actor: "tester",
            source: "unit-test",
            commandLine: ["calbuddy", "addEvent"],
            targetIdentifiers: ["event-1"],
            beforeSnapshot: nil,
            afterSnapshot: snapshot,
            inverseOperation: ActionInverseOperation(
                kind: .deleteEvent,
                targetIdentifier: "event-1",
                snapshot: nil
            ),
            errorDetails: nil,
            forced: false,
            revertedActionID: nil
        )
    }

    private func sampleSnapshot(id: String, title: String) -> CalendarEventSnapshot {
        CalendarEventSnapshot(
            calendarItemIdentifier: id,
            eventIdentifier: id,
            externalIdentifier: "external-\(id)",
            calendarIdentifier: "calendar-1",
            calendarTitle: "Work",
            title: title,
            startDate: Date(timeIntervalSince1970: 1_800_000_000),
            endDate: Date(timeIntervalSince1970: 1_800_003_600),
            isAllDay: false,
            location: nil,
            notes: nil,
            url: nil,
            alarms: [15],
            timeZoneIdentifier: "UTC",
            availabilityRawValue: nil,
            unsupportedRestoreReasons: []
        )
    }

    private func tempDatabasePath() -> String {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("calbuddy-tests-\(UUID().uuidString)", isDirectory: true)
        return directory.appendingPathComponent("action-log.sqlite3").path
    }

    private func rawExec(path: String, sql: String) -> Int32 {
        var db: OpaquePointer?
        guard sqlite3_open(path, &db) == SQLITE_OK else { return SQLITE_ERROR }
        defer { sqlite3_close(db) }
        return sqlite3_exec(db, sql, nil, nil, nil)
    }

    private func queryCount(path: String, table: String) -> Int {
        var db: OpaquePointer?
        guard sqlite3_open(path, &db) == SQLITE_OK else { return -1 }
        defer { sqlite3_close(db) }

        var statement: OpaquePointer?
        sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM \(table);", -1, &statement, nil)
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else { return -1 }
        return Int(sqlite3_column_int(statement, 0))
    }
}
