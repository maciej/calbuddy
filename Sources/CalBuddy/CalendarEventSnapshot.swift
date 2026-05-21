import EventKit
import Foundation

struct CalendarEventSnapshot: Codable, Equatable, Sendable {
    static let schemaVersion = 1

    var schemaVersion: Int = CalendarEventSnapshot.schemaVersion
    var calendarItemIdentifier: String?
    var eventIdentifier: String?
    var externalIdentifier: String?
    var calendarIdentifier: String?
    var calendarTitle: String
    var title: String
    var startDate: Date
    var endDate: Date
    var isAllDay: Bool
    var location: String?
    var notes: String?
    var url: String?
    var alarms: [Int]
    var timeZoneIdentifier: String?
    var availabilityRawValue: Int?
    var unsupportedRestoreReasons: [String]

    var preferredIdentifier: String? {
        eventIdentifier ?? calendarItemIdentifier ?? externalIdentifier
    }

    func matchesRestorableState(_ other: CalendarEventSnapshot) -> Bool {
        calendarIdentifier == other.calendarIdentifier &&
            calendarTitle == other.calendarTitle &&
            title == other.title &&
            startDate == other.startDate &&
            endDate == other.endDate &&
            isAllDay == other.isAllDay &&
            normalized(location) == normalized(other.location) &&
            normalized(notes) == normalized(other.notes) &&
            normalized(url) == normalized(other.url) &&
            alarms == other.alarms &&
            timeZoneIdentifier == other.timeZoneIdentifier &&
            availabilityRawValue == other.availabilityRawValue
    }

    func validateDeleteRestorable() throws {
        guard unsupportedRestoreReasons.isEmpty else {
            throw CalendarActionError.unsupportedSnapshot(
                "Cannot delete event because it cannot be fully restored: \(unsupportedRestoreReasons.joined(separator: ", "))"
            )
        }
    }
}

private func normalized(_ value: String?) -> String? {
    guard let value, !value.isEmpty else { return nil }
    return value
}

extension CalendarEventSnapshot {
    init(event: EKEvent) {
        let alarmMinutes = (event.alarms ?? []).compactMap { alarm -> Int? in
            guard alarm.absoluteDate == nil else { return nil }
            return Int((-alarm.relativeOffset / 60).rounded())
        }

        var unsupported: [String] = []
        if let alarms = event.alarms, alarms.contains(where: { $0.absoluteDate != nil }) {
            unsupported.append("absolute alarms")
        }
        if let recurrenceRules = event.recurrenceRules, !recurrenceRules.isEmpty {
            unsupported.append("recurrence rules")
        }
        if let attendees = event.attendees, !attendees.isEmpty {
            unsupported.append("attendees")
        }

        self.init(
            calendarItemIdentifier: event.calendarItemIdentifier,
            eventIdentifier: event.eventIdentifier,
            externalIdentifier: event.calendarItemExternalIdentifier,
            calendarIdentifier: event.calendar.calendarIdentifier,
            calendarTitle: event.calendar.title,
            title: event.title ?? "",
            startDate: event.startDate,
            endDate: event.endDate,
            isAllDay: event.isAllDay,
            location: normalized(event.location),
            notes: normalized(event.notes),
            url: event.url?.absoluteString,
            alarms: alarmMinutes,
            timeZoneIdentifier: event.timeZone?.identifier,
            availabilityRawValue: event.availability.rawValue,
            unsupportedRestoreReasons: unsupported
        )
    }
}

enum CalendarActionError: Error, CustomStringConvertible, Equatable {
    case missingRequired(String)
    case eventNotFound(String)
    case actionNotFound(String)
    case conflict(String)
    case unsupportedSnapshot(String)
    case invalidAction(String)
    case logFailure(String)

    var description: String {
        switch self {
        case .missingRequired(let message),
             .eventNotFound(let message),
             .actionNotFound(let message),
             .conflict(let message),
             .unsupportedSnapshot(let message),
             .invalidAction(let message),
             .logFailure(let message):
            return message
        }
    }
}
