import EventKit
import Foundation

/// Format calendar type to string
func calendarTypeString(_ type: EKCalendarType) -> String {
    switch type {
    case .local: return "Local"
    case .calDAV: return "CalDAV"
    case .exchange: return "Exchange"
    case .subscription: return "Subscription"
    case .birthday: return "Birthday"
    @unknown default: return "Unknown"
    }
}

/// Format calendar source type to string
func sourceTypeString(_ type: EKSourceType) -> String {
    switch type {
    case .local: return "Local"
    case .exchange: return "Exchange"
    case .calDAV: return "CalDAV"
    case .mobileMe: return "MobileMe"
    case .subscribed: return "Subscribed"
    case .birthdays: return "Birthdays"
    @unknown default: return "Unknown"
    }
}

/// Get hex color from CGColor
func hexColor(from cgColor: CGColor) -> String {
    guard let components = cgColor.components, components.count >= 3 else {
        return "#000000"
    }
    let r = Int(components[0] * 255)
    let g = Int(components[1] * 255)
    let b = Int(components[2] * 255)
    return String(format: "#%02X%02X%02X", r, g, b)
}

/// Format calendars list
func formatCalendars(_ calendars: [EKCalendar], formatOutput: Bool) -> String {
    var output: [String] = []
    for cal in calendars {
        let color = hexColor(from: cal.cgColor)
        let type = calendarTypeString(cal.type)
        let source = cal.source?.title ?? "Unknown"
        if formatOutput {
            output.append("\(ANSIColor.bold)\(cal.title)\(ANSIColor.reset) (\(type), \(source)) \(color)")
        } else {
            output.append("\(cal.title) (\(type), \(source)) \(color)")
        }
    }
    return output.joined(separator: "\n")
}
