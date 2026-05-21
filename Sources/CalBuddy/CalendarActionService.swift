import EventKit
import Foundation

protocol CalendarMutationClient {
    func snapshot(uid: String) throws -> CalendarEventSnapshot?
    func createEvent(options: AddEventOptions) throws -> CalendarEventSnapshot
    func updateEvent(uid: String, options: EditEventOptions) throws -> CalendarEventSnapshot
    func deleteEvent(uid: String) throws
    func restoreEvent(snapshot: CalendarEventSnapshot, preferredUID: String?, allowCreate: Bool) throws -> CalendarEventSnapshot
}

final class CalendarActionService {
    private let calendar: CalendarMutationClient
    private let actionLog: ActionLogStore
    private let commandLine: [String]
    private let actor: String?
    private let source: String

    init(
        calendar: CalendarMutationClient,
        actionLog: ActionLogStore,
        commandLine: [String] = CommandLine.arguments,
        actor: String? = ProcessInfo.processInfo.environment["USER"],
        source: String = "calbuddy-cli"
    ) {
        self.calendar = calendar
        self.actionLog = actionLog
        self.commandLine = commandLine
        self.actor = actor
        self.source = source
    }

    func addEvent(options: AddEventOptions) throws -> CalendarEventSnapshot {
        try actionLog.ensureReady()
        let after = try calendar.createEvent(options: options)
        let entry = makeEntry(
            actionType: .createEvent,
            targetIdentifiers: identifiers(from: after),
            before: nil,
            after: after,
            inverse: ActionInverseOperation(
                kind: .deleteEvent,
                targetIdentifier: after.preferredIdentifier,
                snapshot: nil
            )
        )
        try actionLog.append(entry)
        return after
    }

    func editEvent(options: EditEventOptions) throws -> CalendarEventSnapshot {
        guard !options.uid.isEmpty else {
            throw CalendarActionError.missingRequired("--uid is required for editEvent")
        }
        try actionLog.ensureReady()
        guard let before = try calendar.snapshot(uid: options.uid) else {
            throw CalendarActionError.eventNotFound("No event found with UID: \(options.uid)")
        }
        let after = try calendar.updateEvent(uid: options.uid, options: options)
        let entry = makeEntry(
            actionType: .updateEvent,
            targetIdentifiers: identifiers(from: after),
            before: before,
            after: after,
            inverse: ActionInverseOperation(
                kind: .restoreEvent,
                targetIdentifier: after.preferredIdentifier,
                snapshot: before
            )
        )
        try actionLog.append(entry)
        return after
    }

    func deleteEvent(uid: String) throws {
        guard !uid.isEmpty else {
            throw CalendarActionError.missingRequired("--uid is required for deleteEvent")
        }
        try actionLog.ensureReady()
        guard let before = try calendar.snapshot(uid: uid) else {
            throw CalendarActionError.eventNotFound("No event found with UID: \(uid)")
        }
        try before.validateDeleteRestorable()
        try calendar.deleteEvent(uid: uid)
        let entry = makeEntry(
            actionType: .deleteEvent,
            targetIdentifiers: identifiers(from: before),
            before: before,
            after: nil,
            inverse: ActionInverseOperation(
                kind: .recreateEvent,
                targetIdentifier: before.preferredIdentifier,
                snapshot: before
            )
        )
        try actionLog.append(entry)
    }

    func revertAction(actionID: String, force: Bool) throws -> CalendarEventSnapshot? {
        guard !actionID.isEmpty else {
            throw CalendarActionError.missingRequired("--actionID is required for revertAction")
        }
        try actionLog.ensureReady()
        guard let original = try actionLog.get(actionID: actionID) else {
            throw CalendarActionError.actionNotFound("No action log entry found with ID: \(actionID)")
        }
        guard original.actionType != .revertAction else {
            throw CalendarActionError.invalidAction("Cannot revert a revert action")
        }

        let result: CalendarEventSnapshot?
        switch original.actionType {
        case .createEvent:
            result = try revertCreate(original, force: force)
        case .updateEvent:
            result = try revertUpdate(original, force: force)
        case .deleteEvent:
            result = try revertDelete(original, force: force)
        case .revertAction:
            result = nil
        }

        let entry = makeEntry(
            actionType: .revertAction,
            targetIdentifiers: original.targetIdentifiers,
            before: original.afterSnapshot,
            after: result,
            inverse: ActionInverseOperation(
                kind: .restoreEvent,
                targetIdentifier: result?.preferredIdentifier,
                snapshot: original.afterSnapshot
            ),
            forced: force,
            revertedActionID: original.actionID
        )
        try actionLog.append(entry)
        return result
    }

    private func revertCreate(_ original: ActionLogEntry, force: Bool) throws -> CalendarEventSnapshot? {
        guard let after = original.afterSnapshot,
              let uid = original.inverseOperation.targetIdentifier ?? after.preferredIdentifier
        else {
            throw CalendarActionError.invalidAction("Create action is missing after-state target data")
        }

        let current = try calendar.snapshot(uid: uid)
        if !force {
            guard let current, current.matchesRestorableState(after) else {
                throw CalendarActionError.conflict("Current event state does not match the logged after-state")
            }
        }
        if current != nil {
            try calendar.deleteEvent(uid: uid)
        }
        return nil
    }

    private func revertUpdate(_ original: ActionLogEntry, force: Bool) throws -> CalendarEventSnapshot? {
        guard let before = original.beforeSnapshot,
              let after = original.afterSnapshot,
              let uid = original.inverseOperation.targetIdentifier ?? after.preferredIdentifier
        else {
            throw CalendarActionError.invalidAction("Update action is missing before/after target data")
        }

        let current = try calendar.snapshot(uid: uid)
        if !force {
            guard let current, current.matchesRestorableState(after) else {
                throw CalendarActionError.conflict("Current event state does not match the logged after-state")
            }
        }
        return try calendar.restoreEvent(snapshot: before, preferredUID: uid, allowCreate: force)
    }

    private func revertDelete(_ original: ActionLogEntry, force: Bool) throws -> CalendarEventSnapshot? {
        guard let before = original.beforeSnapshot else {
            throw CalendarActionError.invalidAction("Delete action is missing before-state data")
        }
        let uid = original.inverseOperation.targetIdentifier ?? before.preferredIdentifier
        if let uid, try calendar.snapshot(uid: uid) != nil, !force {
            throw CalendarActionError.conflict("Cannot recreate deleted event because a target event already exists")
        }
        return try calendar.restoreEvent(snapshot: before, preferredUID: uid, allowCreate: true)
    }

    private func makeEntry(
        actionType: ActionType,
        targetIdentifiers: [String],
        before: CalendarEventSnapshot?,
        after: CalendarEventSnapshot?,
        inverse: ActionInverseOperation,
        forced: Bool = false,
        revertedActionID: String? = nil
    ) -> ActionLogEntry {
        ActionLogEntry(
            actionID: UUID().uuidString,
            timestamp: Date(),
            schemaVersion: ActionLogEntry.schemaVersion,
            actionType: actionType,
            status: .succeeded,
            actor: actor,
            source: source,
            commandLine: commandLine,
            targetIdentifiers: targetIdentifiers,
            beforeSnapshot: before,
            afterSnapshot: after,
            inverseOperation: inverse,
            errorDetails: nil,
            forced: forced,
            revertedActionID: revertedActionID
        )
    }

    private func identifiers(from snapshot: CalendarEventSnapshot) -> [String] {
        [
            snapshot.eventIdentifier,
            snapshot.calendarItemIdentifier,
            snapshot.externalIdentifier,
        ].compactMap { $0 }.uniquePreservingOrder()
    }
}

private extension Array where Element: Hashable {
    func uniquePreservingOrder() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

final class EventKitCalendarMutationClient: CalendarMutationClient {
    private let store: EKEventStore

    init(store: EKEventStore) {
        self.store = store
    }

    func snapshot(uid: String) throws -> CalendarEventSnapshot? {
        findEvent(uid: uid).map(CalendarEventSnapshot.init(event:))
    }

    func createEvent(options: AddEventOptions) throws -> CalendarEventSnapshot {
        guard !options.title.isEmpty else {
            throw EventCreatorError.missingRequired("--title is required")
        }
        guard !options.calendarName.isEmpty else {
            throw EventCreatorError.missingRequired("--calendar is required")
        }
        guard !options.startString.isEmpty else {
            throw EventCreatorError.missingRequired("--start is required")
        }
        guard let calendar = calendar(named: options.calendarName) else {
            let available = store.calendars(for: .event).map { $0.title }.joined(separator: ", ")
            throw EventCreatorError.calendarNotFound("Calendar '\(options.calendarName)' not found. Available: \(available)")
        }
        guard let startDate = parseDateString(options.startString) else {
            throw EventCreatorError.invalidDate("Could not parse start date: \(options.startString)")
        }

        let endDate: Date
        if let endString = options.endString {
            guard let parsed = parseDateString(endString) else {
                throw EventCreatorError.invalidDate("Could not parse end date: \(endString)")
            }
            endDate = parsed
        } else if let duration = options.duration {
            endDate = startDate.addingTimeInterval(Double(duration) * 60)
        } else {
            endDate = startDate.addingTimeInterval(3600)
        }

        let event = EKEvent(eventStore: store)
        event.title = options.title
        event.calendar = calendar
        event.startDate = startDate
        event.endDate = endDate
        event.isAllDay = options.allDay
        event.location = options.location
        event.notes = options.notes
        if let urlString = options.url {
            event.url = URL(string: urlString)
        }
        for minutes in options.alarms {
            event.addAlarm(EKAlarm(relativeOffset: TimeInterval(-minutes * 60)))
        }

        try store.save(event, span: .thisEvent)
        return CalendarEventSnapshot(event: event)
    }

    func updateEvent(uid: String, options: EditEventOptions) throws -> CalendarEventSnapshot {
        guard let event = findEvent(uid: uid) else {
            throw EventEditorError.eventNotFound("No event found with UID: \(uid)")
        }
        let originalDuration = event.endDate.timeIntervalSince(event.startDate)

        if let title = options.title {
            event.title = title
        }
        if let startString = options.startString {
            guard let startDate = parseDateString(startString) else {
                throw EventEditorError.invalidDate("Could not parse start date: \(startString)")
            }
            event.startDate = startDate
            if let duration = options.duration {
                event.endDate = startDate.addingTimeInterval(Double(duration) * 60)
            } else if options.endString == nil {
                event.endDate = startDate.addingTimeInterval(originalDuration > 0 ? originalDuration : 3600)
            }
        }
        if let endString = options.endString {
            guard let endDate = parseDateString(endString) else {
                throw EventEditorError.invalidDate("Could not parse end date: \(endString)")
            }
            event.endDate = endDate
        } else if options.startString == nil, let duration = options.duration {
            event.endDate = event.startDate.addingTimeInterval(Double(duration) * 60)
        }
        if let allDay = options.allDay {
            event.isAllDay = allDay
        }
        if let location = options.location {
            event.location = location
        }
        if let notes = options.notes {
            event.notes = notes
        }
        if let urlString = options.url {
            event.url = URL(string: urlString)
        }
        if let alarms = options.alarms {
            replaceAlarms(on: event, with: alarms)
        }

        try store.save(event, span: .thisEvent)
        return CalendarEventSnapshot(event: event)
    }

    func deleteEvent(uid: String) throws {
        guard let event = findEvent(uid: uid) else {
            throw CalendarActionError.eventNotFound("No event found with UID: \(uid)")
        }
        try store.remove(event, span: .thisEvent)
    }

    func restoreEvent(snapshot: CalendarEventSnapshot, preferredUID: String?, allowCreate: Bool) throws -> CalendarEventSnapshot {
        let target = preferredUID.flatMap(findEvent(uid:)) ?? snapshot.preferredIdentifier.flatMap(findEvent(uid:))
        if let target {
            try apply(snapshot, to: target)
            try store.save(target, span: .thisEvent)
            return CalendarEventSnapshot(event: target)
        }

        guard allowCreate else {
            throw CalendarActionError.eventNotFound("No event found to restore")
        }

        let event = EKEvent(eventStore: store)
        try apply(snapshot, to: event)
        try store.save(event, span: .thisEvent)
        return CalendarEventSnapshot(event: event)
    }

    private func apply(_ snapshot: CalendarEventSnapshot, to event: EKEvent) throws {
        guard let calendar = calendar(identifier: snapshot.calendarIdentifier)
            ?? calendar(named: snapshot.calendarTitle)
        else {
            throw EventCreatorError.calendarNotFound("Calendar '\(snapshot.calendarTitle)' not found")
        }

        event.calendar = calendar
        event.title = snapshot.title
        event.startDate = snapshot.startDate
        event.endDate = snapshot.endDate
        event.isAllDay = snapshot.isAllDay
        event.location = snapshot.location
        event.notes = snapshot.notes
        event.url = snapshot.url.flatMap(URL.init(string:))
        if let timeZoneIdentifier = snapshot.timeZoneIdentifier {
            event.timeZone = TimeZone(identifier: timeZoneIdentifier)
        }
        if let rawValue = snapshot.availabilityRawValue,
           let availability = EKEventAvailability(rawValue: rawValue)
        {
            event.availability = availability
        }
        replaceAlarms(on: event, with: snapshot.alarms)
    }

    private func replaceAlarms(on event: EKEvent, with minutes: [Int]) {
        if let existing = event.alarms {
            for alarm in existing {
                event.removeAlarm(alarm)
            }
        }
        for minute in minutes {
            event.addAlarm(EKAlarm(relativeOffset: TimeInterval(-minute * 60)))
        }
    }

    private func calendar(identifier: String?) -> EKCalendar? {
        guard let identifier else { return nil }
        return store.calendars(for: .event).first { $0.calendarIdentifier == identifier }
    }

    private func calendar(named name: String) -> EKCalendar? {
        store.calendars(for: .event).first { $0.title == name }
    }

    private func findEvent(uid: String) -> EKEvent? {
        let uidParts = uid.split(separator: ":", maxSplits: 1).map(String.init)
        let cal = Calendar.current
        let now = Date()
        let start = cal.date(byAdding: .year, value: -1, to: now)!
        let end = cal.date(byAdding: .year, value: 1, to: now)!
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let events = store.events(matching: predicate)

        for event in events {
            if event.eventIdentifier == uid ||
                event.calendarItemIdentifier == uid ||
                event.calendarItemExternalIdentifier == uid
            {
                return event
            }
        }

        for event in events {
            for part in uidParts {
                if event.eventIdentifier == part ||
                    event.calendarItemIdentifier == part ||
                    event.calendarItemExternalIdentifier == part
                {
                    return event
                }
            }
        }

        if let item = store.calendarItem(withIdentifier: uid) as? EKEvent {
            return item
        }

        return nil
    }
}
