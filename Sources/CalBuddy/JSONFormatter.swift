import EventKit
import Foundation

struct EventQueryMetadata: Sendable {
    let startDate: Date
    let endDate: Date
    let startInput: String?
    let endInput: String?
    let referenceNow: Date?
}

private struct EventsJSONResponse: Encodable {
    let schemaVersion: String
    let command: String
    let query: EventsQueryJSON
    let count: Int
    let events: [EventJSON]
    let generatedAt: String?
    let timezone: String?
    let displayDefaults: EventsDisplayDefaultsJSON?
}

private struct EventsQueryJSON: Encodable {
    let start: String
    let end: String
    let startInput: String?
    let endInput: String?
    let referenceNow: String?
}

private struct EventsDisplayDefaultsJSON: Encodable {
    let eventLineFields: [String]
    let dateFormat: String
    let timeFormat: String
}

private struct EventJSON: Encodable {
    let id: String
    let calendarID: String
    let calendar: String
    let title: String
    let start: String
    let end: String
    let allDay: Bool
    let location: String?
    let eventID: String?
    let durationMinutes: Int?
    let notes: String?
    let url: String?
    let attendees: [String]?
    let calendarInfo: CalendarJSONReference?
    let display: EventDisplayJSON?
}

private struct CalendarJSONReference: Encodable {
    let calendarID: String
    let title: String
    let type: String
    let sourceTitle: String
    let sourceType: String
    let colorHex: String
}

private struct EventDisplayJSON: Encodable {
    let datetime: String
    let line: String
}

private struct CalendarsJSONResponse: Encodable {
    let schemaVersion: String
    let command: String
    let count: Int
    let calendars: [CalendarJSON]
    let generatedAt: String?
    let timezone: String?
    let displayDefaults: CalendarDisplayDefaultsJSON?
}

private struct CalendarDisplayDefaultsJSON: Encodable {
    let lineFields: [String]
}

private struct CalendarJSON: Encodable {
    let id: String
    let title: String
    let type: String
    let source: String
    let colorHex: String
    let sourceType: String?
    let allowsContentModifications: Bool?
    let displayLine: String?
}

private func normalizedText(_ value: String?) -> String? {
    guard let value else { return nil }
    return value.isEmpty ? nil : value
}

private func iso8601String(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    formatter.timeZone = TimeZone.current
    return formatter.string(from: date)
}

private func makeJSONEncoder(mode: JSONMode) -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    var formatting: JSONEncoder.OutputFormatting = [.withoutEscapingSlashes]
    if mode == .verbose {
        formatting.formUnion([.prettyPrinted, .sortedKeys])
    }
    encoder.outputFormatting = formatting
    return encoder
}

private func calendarReferenceJSON(_ calendar: EKCalendar) -> CalendarJSONReference {
    CalendarJSONReference(
        calendarID: calendar.calendarIdentifier,
        title: calendar.title,
        type: calendarTypeString(calendar.type),
        sourceTitle: calendar.source.title,
        sourceType: sourceTypeString(calendar.source.sourceType),
        colorHex: hexColor(from: calendar.cgColor)
    )
}

private func eventJSON(_ event: EKEvent, options: ParsedOptions, mode: JSONMode) -> EventJSON {
    let title = normalizedText(event.title) ?? "(No Title)"
    let dateTimeText = formatEventDateTime(
        startDate: event.startDate,
        endDate: event.endDate,
        isAllDay: event.isAllDay,
        options: options
    )
    let lineText = "[\(event.calendar.title)] \(dateTimeText) \(title)"

    if mode == .verbose {
        let attendees = (event.attendees ?? []).compactMap { attendee in
            attendee.name ?? normalizedText(attendee.url.absoluteString)
        }
        return EventJSON(
            id: event.calendarItemIdentifier,
            calendarID: event.calendar.calendarIdentifier,
            calendar: event.calendar.title,
            title: title,
            start: iso8601String(event.startDate),
            end: iso8601String(event.endDate),
            allDay: event.isAllDay,
            location: normalizedText(event.location),
            eventID: event.eventIdentifier,
            durationMinutes: max(0, Int(event.endDate.timeIntervalSince(event.startDate) / 60)),
            notes: normalizedText(event.notes),
            url: event.url?.absoluteString,
            attendees: attendees,
            calendarInfo: calendarReferenceJSON(event.calendar),
            display: EventDisplayJSON(datetime: dateTimeText, line: lineText)
        )
    }

    return EventJSON(
        id: event.calendarItemIdentifier,
        calendarID: event.calendar.calendarIdentifier,
        calendar: event.calendar.title,
        title: title,
        start: iso8601String(event.startDate),
        end: iso8601String(event.endDate),
        allDay: event.isAllDay,
        location: normalizedText(event.location),
        eventID: nil,
        durationMinutes: nil,
        notes: nil,
        url: nil,
        attendees: nil,
        calendarInfo: nil,
        display: nil
    )
}

func formatEventsJSON(events: [EKEvent], options: ParsedOptions, mode: JSONMode, command: String, query: EventQueryMetadata) throws -> String {
    let verbose = mode == .verbose
    let response = EventsJSONResponse(
        schemaVersion: verbose ? "2.0" : "2.0-compact",
        command: command,
        query: EventsQueryJSON(
            start: iso8601String(query.startDate),
            end: iso8601String(query.endDate),
            startInput: query.startInput,
            endInput: query.endInput,
            referenceNow: query.referenceNow.map(iso8601String)
        ),
        count: events.count,
        events: events.map { eventJSON($0, options: options, mode: mode) },
        generatedAt: verbose ? iso8601String(Date()) : nil,
        timezone: verbose ? TimeZone.current.identifier : nil,
        displayDefaults: verbose
            ? EventsDisplayDefaultsJSON(
                eventLineFields: ["calendar_name", "datetime", "title"],
                dateFormat: options.dateFormat,
                timeFormat: options.timeFormat
            )
            : nil
    )

    let encoded = try makeJSONEncoder(mode: mode).encode(response)
    return String(decoding: encoded, as: UTF8.self)
}

func formatCalendarsJSON(_ calendars: [EKCalendar], mode: JSONMode) throws -> String {
    let verbose = mode == .verbose
    let payload = calendars.map { calendar in
        let type = calendarTypeString(calendar.type)
        let sourceTitle = calendar.source.title
        let colorHex = hexColor(from: calendar.cgColor)
        let line = "\(calendar.title) (\(type), \(sourceTitle)) \(colorHex)"
        return CalendarJSON(
            id: calendar.calendarIdentifier,
            title: calendar.title,
            type: type,
            source: sourceTitle,
            colorHex: colorHex,
            sourceType: verbose ? sourceTypeString(calendar.source.sourceType) : nil,
            allowsContentModifications: verbose ? calendar.allowsContentModifications : nil,
            displayLine: verbose ? line : nil
        )
    }

    let response = CalendarsJSONResponse(
        schemaVersion: verbose ? "2.0" : "2.0-compact",
        command: "calendars",
        count: payload.count,
        calendars: payload,
        generatedAt: verbose ? iso8601String(Date()) : nil,
        timezone: verbose ? TimeZone.current.identifier : nil,
        displayDefaults: verbose
            ? CalendarDisplayDefaultsJSON(lineFields: ["title", "type", "source", "color"])
            : nil
    )

    let encoded = try makeJSONEncoder(mode: mode).encode(response)
    return String(decoding: encoded, as: UTF8.self)
}
