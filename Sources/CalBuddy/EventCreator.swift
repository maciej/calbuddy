import EventKit
import Foundation

/// Creates calendar events using EventKit
struct EventCreator {
    let store: EKEventStore

    init(store: EKEventStore) {
        self.store = store
    }

    /// Create an event from AddEventOptions. Returns the event identifier on success.
    func createEvent(options: AddEventOptions) throws -> String {
        // Validate required fields
        guard !options.title.isEmpty else {
            throw EventCreatorError.missingRequired("--title is required")
        }
        guard !options.calendarName.isEmpty else {
            throw EventCreatorError.missingRequired("--calendar is required")
        }
        guard !options.startString.isEmpty else {
            throw EventCreatorError.missingRequired("--start is required")
        }

        // Find calendar
        let calendars = store.calendars(for: .event)
        guard let calendar = calendars.first(where: { $0.title == options.calendarName }) else {
            let available = calendars.map { $0.title }.joined(separator: ", ")
            throw EventCreatorError.calendarNotFound("Calendar '\(options.calendarName)' not found. Available: \(available)")
        }

        // Parse start date
        guard let startDate = parseDateString(options.startString) else {
            throw EventCreatorError.invalidDate("Could not parse start date: \(options.startString)")
        }

        // Determine end date
        let endDate: Date
        if let endString = options.endString {
            guard let parsed = parseDateString(endString) else {
                throw EventCreatorError.invalidDate("Could not parse end date: \(endString)")
            }
            endDate = parsed
        } else if let duration = options.duration {
            endDate = startDate.addingTimeInterval(Double(duration) * 60)
        } else {
            // Default: 1 hour
            endDate = startDate.addingTimeInterval(3600)
        }

        // Create the event
        let event = EKEvent(eventStore: store)
        event.title = options.title
        event.calendar = calendar
        event.startDate = startDate
        event.endDate = endDate
        event.isAllDay = options.allDay

        // Optional fields
        if let location = options.location {
            event.location = location
        }
        if let notes = options.notes {
            event.notes = notes
        }
        if let urlString = options.url, let url = URL(string: urlString) {
            event.url = url
        }

        // Alarms
        for minutes in options.alarms {
            let alarm = EKAlarm(relativeOffset: TimeInterval(-minutes * 60))
            event.addAlarm(alarm)
        }

        // Save
        try store.save(event, span: .thisEvent)

        guard let identifier = event.eventIdentifier else {
            throw EventCreatorError.saveFailed("Event saved but no identifier returned")
        }

        return identifier
    }
}

enum EventCreatorError: Error, CustomStringConvertible {
    case missingRequired(String)
    case calendarNotFound(String)
    case invalidDate(String)
    case saveFailed(String)

    var description: String {
        switch self {
        case .missingRequired(let msg): return msg
        case .calendarNotFound(let msg): return msg
        case .invalidDate(let msg): return msg
        case .saveFailed(let msg): return msg
        }
    }
}
