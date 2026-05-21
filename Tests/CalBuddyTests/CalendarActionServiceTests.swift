import XCTest
@testable import CalBuddy

final class CalendarActionServiceTests: XCTestCase {
    func testCreateLogsAndRevertDeletes() throws {
        let fake = FakeCalendarMutationClient()
        let (service, store) = makeService(calendar: fake)

        let created = try service.addEvent(options: addOptions(title: "Planning"))
        XCTAssertNotNil(try fake.snapshot(uid: created.eventIdentifier!))

        let createEntry = try serviceEntries(store).first!
        XCTAssertEqual(createEntry.actionType, .createEvent)
        XCTAssertNil(createEntry.beforeSnapshot)
        XCTAssertEqual(createEntry.afterSnapshot?.title, "Planning")

        _ = try service.revertAction(actionID: createEntry.actionID, force: false)
        XCTAssertNil(try fake.snapshot(uid: created.eventIdentifier!))

        let entries = try serviceEntries(store)
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].actionType, .revertAction)
        XCTAssertEqual(entries[0].revertedActionID, createEntry.actionID)
    }

    func testEditLogsBeforeAfterAndRevertRestores() throws {
        let fake = FakeCalendarMutationClient()
        let original = fake.insert(title: "Original")
        let (service, store) = makeService(calendar: fake)

        var options = EditEventOptions()
        options.uid = original.eventIdentifier!
        options.title = "Updated"
        let updated = try service.editEvent(options: options)
        XCTAssertEqual(updated.title, "Updated")

        let editEntry = try serviceEntries(store).first!
        XCTAssertEqual(editEntry.actionType, .updateEvent)
        XCTAssertEqual(editEntry.beforeSnapshot?.title, "Original")
        XCTAssertEqual(editEntry.afterSnapshot?.title, "Updated")

        let restored = try service.revertAction(actionID: editEntry.actionID, force: false)
        XCTAssertEqual(restored?.title, "Original")
        XCTAssertEqual(try fake.snapshot(uid: original.eventIdentifier!)?.title, "Original")
    }

    func testDeleteLogsBeforeNullAndRevertRecreates() throws {
        let fake = FakeCalendarMutationClient()
        let original = fake.insert(title: "Temporary")
        let (service, store) = makeService(calendar: fake)

        try service.deleteEvent(uid: original.eventIdentifier!)
        XCTAssertNil(try fake.snapshot(uid: original.eventIdentifier!))

        let deleteEntry = try serviceEntries(store).first!
        XCTAssertEqual(deleteEntry.actionType, .deleteEvent)
        XCTAssertEqual(deleteEntry.beforeSnapshot?.title, "Temporary")
        XCTAssertNil(deleteEntry.afterSnapshot)

        let recreated = try service.revertAction(actionID: deleteEntry.actionID, force: false)
        XCTAssertEqual(recreated?.title, "Temporary")
        XCTAssertNotNil(try fake.snapshot(uid: original.eventIdentifier!))
    }

    func testDeleteRefusesUnsupportedSnapshots() throws {
        let fake = FakeCalendarMutationClient()
        let original = fake.insert(title: "Recurring", unsupportedRestoreReasons: ["recurrence rules"])
        let (service, _) = makeService(calendar: fake)

        XCTAssertThrowsError(try service.deleteEvent(uid: original.eventIdentifier!)) { error in
            XCTAssertTrue(String(describing: error).contains("cannot be fully restored"))
        }
        XCTAssertNotNil(try fake.snapshot(uid: original.eventIdentifier!))
    }

    func testRevertRefusesConflictUnlessForced() throws {
        let fake = FakeCalendarMutationClient()
        let original = fake.insert(title: "Original")
        let (service, store) = makeService(calendar: fake)

        var options = EditEventOptions()
        options.uid = original.eventIdentifier!
        options.title = "Updated"
        _ = try service.editEvent(options: options)

        let editEntry = try serviceEntries(store).first!
        fake.setTitle("Drifted", uid: original.eventIdentifier!)

        XCTAssertThrowsError(try service.revertAction(actionID: editEntry.actionID, force: false)) { error in
            XCTAssertTrue(String(describing: error).contains("does not match"))
        }
        XCTAssertEqual(try fake.snapshot(uid: original.eventIdentifier!)?.title, "Drifted")

        let forced = try service.revertAction(actionID: editEntry.actionID, force: true)
        XCTAssertEqual(forced?.title, "Original")
        XCTAssertEqual(try serviceEntries(store).first?.forced, true)
    }

    private func makeService(calendar: FakeCalendarMutationClient) -> (CalendarActionService, ActionLogStore) {
        let store = ActionLogStore(path: tempDatabasePath())
        let service = CalendarActionService(
            calendar: calendar,
            actionLog: store,
            commandLine: ["calbuddy"],
            actor: "tester",
            source: "unit-test"
        )
        return (service, store)
    }

    private func serviceEntries(_ store: ActionLogStore) throws -> [ActionLogEntry] {
        return try store.list(limit: 20)
    }

    private func tempDatabasePath() -> String {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("calbuddy-service-tests-\(UUID().uuidString)", isDirectory: true)
        return directory.appendingPathComponent("action-log.sqlite3").path
    }

    private func addOptions(title: String) -> AddEventOptions {
        AddEventOptions(
            title: title,
            calendarName: "Work",
            startString: "2026-02-10 09:00",
            endString: nil,
            duration: 60,
            allDay: false,
            alarms: [15],
            location: nil,
            notes: nil,
            url: nil
        )
    }
}

private final class FakeCalendarMutationClient: CalendarMutationClient {
    private var events: [String: CalendarEventSnapshot] = [:]
    private var nextID = 1

    func insert(title: String, unsupportedRestoreReasons: [String] = []) -> CalendarEventSnapshot {
        let id = "event-\(nextID)"
        nextID += 1
        let snapshot = makeSnapshot(id: id, title: title, unsupportedRestoreReasons: unsupportedRestoreReasons)
        events[id] = snapshot
        return snapshot
    }

    func setTitle(_ title: String, uid: String) {
        guard var snapshot = events[uid] else { return }
        snapshot.title = title
        events[uid] = snapshot
    }

    func snapshot(uid: String) throws -> CalendarEventSnapshot? {
        find(uid)
    }

    func createEvent(options: AddEventOptions) throws -> CalendarEventSnapshot {
        let id = "event-\(nextID)"
        nextID += 1
        guard let startDate = parseDateString(options.startString) else {
            throw EventCreatorError.invalidDate("Could not parse start date: \(options.startString)")
        }
        let endDate = options.duration.map { startDate.addingTimeInterval(Double($0) * 60) }
            ?? startDate.addingTimeInterval(3600)
        let snapshot = CalendarEventSnapshot(
            calendarItemIdentifier: id,
            eventIdentifier: id,
            externalIdentifier: "external-\(id)",
            calendarIdentifier: "calendar-1",
            calendarTitle: options.calendarName,
            title: options.title,
            startDate: startDate,
            endDate: endDate,
            isAllDay: options.allDay,
            location: options.location,
            notes: options.notes,
            url: options.url,
            alarms: options.alarms,
            timeZoneIdentifier: "UTC",
            availabilityRawValue: nil,
            unsupportedRestoreReasons: []
        )
        events[id] = snapshot
        return snapshot
    }

    func updateEvent(uid: String, options: EditEventOptions) throws -> CalendarEventSnapshot {
        guard var snapshot = find(uid) else {
            throw CalendarActionError.eventNotFound("No event found with UID: \(uid)")
        }
        if let title = options.title {
            snapshot.title = title
        }
        if let startString = options.startString {
            guard let startDate = parseDateString(startString) else {
                throw EventEditorError.invalidDate("Could not parse start date: \(startString)")
            }
            let duration = snapshot.endDate.timeIntervalSince(snapshot.startDate)
            snapshot.startDate = startDate
            snapshot.endDate = startDate.addingTimeInterval(duration)
        }
        if let endString = options.endString {
            guard let endDate = parseDateString(endString) else {
                throw EventEditorError.invalidDate("Could not parse end date: \(endString)")
            }
            snapshot.endDate = endDate
        }
        if let allDay = options.allDay {
            snapshot.isAllDay = allDay
        }
        if let alarms = options.alarms {
            snapshot.alarms = alarms
        }
        if let location = options.location {
            snapshot.location = location
        }
        if let notes = options.notes {
            snapshot.notes = notes
        }
        if let url = options.url {
            snapshot.url = url
        }
        events[snapshot.eventIdentifier!] = snapshot
        return snapshot
    }

    func deleteEvent(uid: String) throws {
        guard let snapshot = find(uid), let id = snapshot.eventIdentifier else {
            throw CalendarActionError.eventNotFound("No event found with UID: \(uid)")
        }
        events.removeValue(forKey: id)
    }

    func restoreEvent(snapshot: CalendarEventSnapshot, preferredUID: String?, allowCreate: Bool) throws -> CalendarEventSnapshot {
        if let preferredUID, var current = find(preferredUID) {
            current = snapshot
            current.eventIdentifier = preferredUID
            current.calendarItemIdentifier = preferredUID
            events[preferredUID] = current
            return current
        }

        guard allowCreate else {
            throw CalendarActionError.eventNotFound("No event found to restore")
        }

        let id = preferredUID ?? snapshot.eventIdentifier ?? "event-\(nextID)"
        if preferredUID == nil && snapshot.eventIdentifier == nil {
            nextID += 1
        }
        var restored = snapshot
        restored.eventIdentifier = id
        restored.calendarItemIdentifier = id
        events[id] = restored
        return restored
    }

    private func find(_ uid: String) -> CalendarEventSnapshot? {
        if let direct = events[uid] {
            return direct
        }
        return events.values.first {
            $0.calendarItemIdentifier == uid ||
                $0.eventIdentifier == uid ||
                $0.externalIdentifier == uid
        }
    }

    private func makeSnapshot(
        id: String,
        title: String,
        unsupportedRestoreReasons: [String]
    ) -> CalendarEventSnapshot {
        CalendarEventSnapshot(
            calendarItemIdentifier: id,
            eventIdentifier: id,
            externalIdentifier: "external-\(id)",
            calendarIdentifier: "calendar-1",
            calendarTitle: "Work",
            title: title,
            startDate: parseDateString("2026-02-10 09:00")!,
            endDate: parseDateString("2026-02-10 10:00")!,
            isAllDay: false,
            location: nil,
            notes: nil,
            url: nil,
            alarms: [15],
            timeZoneIdentifier: "UTC",
            availabilityRawValue: nil,
            unsupportedRestoreReasons: unsupportedRestoreReasons
        )
    }
}
