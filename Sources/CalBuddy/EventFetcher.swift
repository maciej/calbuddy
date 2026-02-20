import EventKit
import Foundation

/// Fetches calendar events from EventKit
final class EventFetcher: @unchecked Sendable {
    let store: EKEventStore

    init() {
        self.store = EKEventStore()
    }

    /// Request calendar access synchronously
    func requestCalendarAccess() -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        var granted = false
        store.requestFullAccessToEvents { g, error in
            granted = g
            if let error = error {
                fputs("Calendar access error: \(error.localizedDescription)\n", stderr)
            }
            semaphore.signal()
        }
        semaphore.wait()
        return granted
    }

    /// Fetch events in a date range
    func fetchEvents(from startDate: Date, to endDate: Date, options: ParsedOptions) -> [EKEvent] {
        var calendars: [EKCalendar]? = nil

        if !options.includeCals.isEmpty {
            calendars = store.calendars(for: .event).filter { options.includeCals.contains($0.title) }
        }

        let predicate = store.predicateForEvents(withStart: startDate, end: endDate, calendars: calendars)
        var events = store.events(matching: predicate)

        // Apply excludeCals filter
        if !options.excludeCals.isEmpty {
            events = events.filter { !options.excludeCals.contains($0.calendar.title) }
        }

        // Exclude all-day events if requested
        if options.excludeAllDayEvents {
            events = events.filter { !$0.isAllDay }
        }

        // Only events from now on
        if options.includeOnlyEventsFromNowOn {
            let now = Date()
            events = events.filter { $0.endDate > now }
        }

        // Sort by start date
        events.sort { $0.startDate < $1.startDate }

        // Apply limit
        if let limit = options.limitItems, limit > 0 {
            events = Array(events.prefix(limit))
        }

        return events
    }

    /// Get all calendars
    func getAllCalendars() -> [EKCalendar] {
        return store.calendars(for: .event).sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

}

/// Parse a date string, supporting YYYY-MM-DD, YYYY-MM-DD HH:MM:SS, and relative formats
func parseDateString(_ str: String) -> Date? {
    // Relative: today, today+N
    if str == "today" {
        return Calendar.current.startOfDay(for: Date())
    }
    if str.hasPrefix("today+") {
        let numStr = String(str.dropFirst("today+".count))
        if let n = Int(numStr) {
            return Calendar.current.date(byAdding: .day, value: n, to: Calendar.current.startOfDay(for: Date()))
        }
    }
    if str.hasPrefix("today-") {
        let numStr = String(str.dropFirst("today-".count))
        if let n = Int(numStr) {
            return Calendar.current.date(byAdding: .day, value: -n, to: Calendar.current.startOfDay(for: Date()))
        }
    }

    // YYYY-MM-DD HH:MM:SS
    let dfFull = DateFormatter()
    dfFull.dateFormat = "yyyy-MM-dd HH:mm:ss"
    dfFull.locale = Locale(identifier: "en_US_POSIX")
    if let date = dfFull.date(from: str) {
        return date
    }

    // YYYY-MM-DD HH:MM
    let dfDateTime = DateFormatter()
    dfDateTime.dateFormat = "yyyy-MM-dd HH:mm"
    dfDateTime.locale = Locale(identifier: "en_US_POSIX")
    if let date = dfDateTime.date(from: str) {
        return date
    }

    // YYYY-MM-DD
    let dfDate = DateFormatter()
    dfDate.dateFormat = "yyyy-MM-dd"
    dfDate.locale = Locale(identifier: "en_US_POSIX")
    if let date = dfDate.date(from: str) {
        return date
    }

    return nil
}
