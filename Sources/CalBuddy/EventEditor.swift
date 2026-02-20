import EventKit
import Foundation

/// Edits existing calendar events using EventKit
struct EventEditor {
    let store: EKEventStore

    init(store: EKEventStore) {
        self.store = store
    }

    /// Edit an event found by UID. Returns the event identifier on success.
    func editEvent(options: EditEventOptions) throws -> String {
        guard !options.uid.isEmpty else {
            throw EventEditorError.missingRequired("--uid is required")
        }

        guard let event = findEvent(uid: options.uid) else {
            throw EventEditorError.eventNotFound("No event found with UID: \(options.uid)")
        }

        // Apply only non-nil fields
        if let title = options.title {
            event.title = title
        }
        if let startString = options.startString {
            guard let startDate = parseDateString(startString) else {
                throw EventEditorError.invalidDate("Could not parse start date: \(startString)")
            }
            event.startDate = startDate
            // Adjust end date if duration provided, otherwise keep relative
            if let duration = options.duration {
                event.endDate = startDate.addingTimeInterval(Double(duration) * 60)
            } else if options.endString == nil {
                // Keep original duration
                let originalDuration = event.endDate.timeIntervalSince(event.startDate)
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
        if let urlString = options.url, let url = URL(string: urlString) {
            event.url = url
        }
        if let alarms = options.alarms {
            // Remove existing alarms
            if let existing = event.alarms {
                for alarm in existing {
                    event.removeAlarm(alarm)
                }
            }
            for minutes in alarms {
                event.addAlarm(EKAlarm(relativeOffset: TimeInterval(-minutes * 60)))
            }
        }

        try store.save(event, span: .thisEvent)

        guard let identifier = event.eventIdentifier else {
            throw EventEditorError.saveFailed("Event saved but no identifier returned")
        }
        return identifier
    }

    /// Find event by UID, trying multiple matching strategies.
    /// Prefers predicate-based search (returns actual occurrences for recurring events)
    /// over calendarItem(withIdentifier:) which returns the master event.
    private func findEvent(uid: String) -> EKEvent? {
        let uidParts = uid.split(separator: ":", maxSplits: 1).map(String.init)

        // 1. Search events in ±1 year range — finds actual occurrences
        let cal = Calendar.current
        let now = Date()
        let start = cal.date(byAdding: .year, value: -1, to: now)!
        let end = cal.date(byAdding: .year, value: 1, to: now)!
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let events = store.events(matching: predicate)

        // First pass: exact match on full UID
        for event in events {
            if event.calendarItemIdentifier == uid ||
               event.calendarItemExternalIdentifier == uid {
                return event
            }
        }

        // Second pass: match on sub-parts (before/after ":")
        for event in events {
            for part in uidParts {
                if event.calendarItemIdentifier == part ||
                   event.calendarItemExternalIdentifier == part {
                    return event
                }
            }
        }

        // 3. Fallback: direct lookup (may return master for recurring events)
        if let item = store.calendarItem(withIdentifier: uid) as? EKEvent {
            return item
        }

        return nil
    }
}

enum EventEditorError: Error, CustomStringConvertible {
    case missingRequired(String)
    case eventNotFound(String)
    case invalidDate(String)
    case saveFailed(String)

    var description: String {
        switch self {
        case .missingRequired(let msg): return msg
        case .eventNotFound(let msg): return msg
        case .invalidDate(let msg): return msg
        case .saveFailed(let msg): return msg
        }
    }
}
