import EventKit
import Foundation

/// Format a Date using strftime-style format string
func formatDate(_ date: Date, format: String) -> String {
    let df = DateFormatter()
    df.dateFormat = strftimeToDateFormat(format)
    df.locale = Locale.current
    return df.string(from: date)
}

/// Convert strftime format to DateFormatter format
func strftimeToDateFormat(_ strftime: String) -> String {
    var result = ""
    var i = strftime.startIndex
    while i < strftime.endIndex {
        let ch = strftime[i]
        if ch == "%" {
            let next = strftime.index(after: i)
            if next < strftime.endIndex {
                let spec = strftime[next]
                switch spec {
                case "Y": result += "yyyy"
                case "y": result += "yy"
                case "m": result += "MM"
                case "d": result += "dd"
                case "H": result += "HH"
                case "I": result += "hh"
                case "M": result += "mm"
                case "S": result += "ss"
                case "p": result += "a"
                case "A": result += "EEEE"
                case "a": result += "EEE"
                case "B": result += "MMMM"
                case "b", "h": result += "MMM"
                case "e": result += "d"
                case "Z": result += "zzz"
                case "z": result += "xx"
                case "%": result += "%"
                default: result += String(spec)
                }
                i = strftime.index(after: next)
            } else {
                result += String(ch)
                i = strftime.index(after: i)
            }
        } else {
            // Escape literal characters that are special in DateFormatter
            let specialChars: Set<Character> = ["a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z",
                                                  "A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z"]
            if specialChars.contains(ch) {
                result += "'\(ch)'"
            } else {
                result += String(ch)
            }
            i = strftime.index(after: i)
        }
    }
    return result
}

/// Check if a property should be shown
func shouldShowProperty(_ prop: String, options: ParsedOptions) -> Bool {
    if !options.includeEventProps.isEmpty {
        return options.includeEventProps.contains(prop)
    }
    if options.excludeEventProps.contains(prop) {
        return false
    }
    return true
}

/// ANSI color codes
struct ANSIColor {
    static let reset = "\u{001B}[0m"
    static let bold = "\u{001B}[1m"
    static let red = "\u{001B}[31m"
    static let green = "\u{001B}[32m"
    static let yellow = "\u{001B}[33m"
    static let blue = "\u{001B}[34m"
    static let magenta = "\u{001B}[35m"
    static let cyan = "\u{001B}[36m"
    static let white = "\u{001B}[37m"
}

/// Build datetime text for an event line.
func formatEventDateTime(startDate: Date, endDate: Date, isAllDay: Bool, options: ParsedOptions) -> String {
    let dateText = formatDate(startDate, format: options.dateFormat)

    if isAllDay {
        return "\(dateText) (all day)"
    }

    let startTime = formatDate(startDate, format: options.timeFormat)
    if options.excludeEndDates {
        return "\(dateText) \(startTime)"
    }

    let endTime = formatDate(endDate, format: options.timeFormat)
    return "\(dateText) \(startTime)-\(endTime)"
}

/// Format a single event line
func formatEvent(_ event: EKEvent, options: ParsedOptions) -> String {
    var parts: [String] = []

    // Calendar name
    if !options.noCalendarNames && shouldShowProperty("title", options: options) {
        if options.formatOutput {
            parts.append("\(ANSIColor.cyan)[\(event.calendar.title)]\(ANSIColor.reset)")
        } else {
            parts.append("[\(event.calendar.title)]")
        }
    }

    // Date/time
    if shouldShowProperty("datetime", options: options) {
        // Include date in per-event lines by default; -sd already provides date in section headers.
        if options.separateByDate {
            if event.isAllDay {
                parts.append("(all day)")
            } else {
                let startTime = formatDate(event.startDate, format: options.timeFormat)
                if options.excludeEndDates {
                    parts.append(startTime)
                } else {
                    let endTime = formatDate(event.endDate, format: options.timeFormat)
                    parts.append("\(startTime)-\(endTime)")
                }
            }
        } else {
            parts.append(formatEventDateTime(startDate: event.startDate, endDate: event.endDate, isAllDay: event.isAllDay, options: options))
        }
    }

    // Title
    if shouldShowProperty("title", options: options) {
        let title = event.title ?? "(No Title)"
        if options.formatOutput {
            parts.append("\(ANSIColor.bold)\(title)\(ANSIColor.reset)")
        } else {
            parts.append(title)
        }
    }

    var lines: [String] = [parts.joined(separator: " ")]

    // UID
    if options.showUIDs {
        lines.append("    UID: \(event.eventIdentifier ?? "unknown")")
    }

    // Location
    if shouldShowProperty("location", options: options), let location = event.location, !location.isEmpty {
        lines.append("    location: \(location)")
    }

    // Notes
    if shouldShowProperty("notes", options: options), let notes = event.notes, !notes.isEmpty {
        let truncated = String(notes.prefix(200)).replacingOccurrences(of: "\n", with: " ")
        lines.append("    notes: \(truncated)")
    }

    // URL
    if shouldShowProperty("url", options: options), let url = event.url {
        lines.append("    url: \(url.absoluteString)")
    }

    // Attendees
    if shouldShowProperty("attendees", options: options), let attendees = event.attendees, !attendees.isEmpty {
        let names = attendees.compactMap { $0.name ?? $0.url.absoluteString }.joined(separator: ", ")
        lines.append("    attendees: \(names)")
    }

    return lines.joined(separator: "\n")
}

/// Format events with -sd (separate by date) grouping
func formatEventsByDate(_ events: [EKEvent], options: ParsedOptions) -> String {
    let cal = Calendar.current
    var dateGroups: [(Date, [EKEvent])] = []
    var currentDate: Date? = nil
    var currentGroup: [EKEvent] = []

    for event in events {
        let eventDay = cal.startOfDay(for: event.startDate)
        if eventDay != currentDate {
            if let cd = currentDate {
                dateGroups.append((cd, currentGroup))
            }
            currentDate = eventDay
            currentGroup = [event]
        } else {
            currentGroup.append(event)
        }
    }
    if let cd = currentDate {
        dateGroups.append((cd, currentGroup))
    }

    // If showEmptyDates, fill in missing dates
    if options.showEmptyDates, let first = events.first?.startDate, let last = events.last?.startDate {
        let firstDay = cal.startOfDay(for: first)
        let lastDay = cal.startOfDay(for: last)
        var allDates: [Date] = []
        var d = firstDay
        while d <= lastDay {
            allDates.append(d)
            d = cal.date(byAdding: .day, value: 1, to: d)!
        }
        let existingDates = Set(dateGroups.map { $0.0 })
        for date in allDates {
            if !existingDates.contains(date) {
                dateGroups.append((date, []))
            }
        }
        dateGroups.sort { $0.0 < $1.0 }
    }

    var output: [String] = []
    for (date, groupEvents) in dateGroups {
        let header = formatDate(date, format: options.dateFormat) + ":"
        if options.formatOutput {
            output.append("\(ANSIColor.bold)\(ANSIColor.magenta)\(header)\(ANSIColor.reset)")
        } else {
            output.append(header)
        }
        if groupEvents.isEmpty {
            // empty section
        } else {
            for event in groupEvents {
                output.append(options.bullet + formatEvent(event, options: options))
            }
        }
    }
    return output.joined(separator: "\n")
}

/// Format events with -sc (separate by calendar) grouping
func formatEventsByCalendar(_ events: [EKEvent], options: ParsedOptions) -> String {
    var calGroups: [String: [EKEvent]] = [:]
    for event in events {
        let calName = event.calendar.title
        calGroups[calName, default: []].append(event)
    }

    var output: [String] = []
    for calName in calGroups.keys.sorted() {
        let header = "\(calName):"
        if options.formatOutput {
            output.append("\(ANSIColor.bold)\(ANSIColor.cyan)\(header)\(ANSIColor.reset)")
        } else {
            output.append(header)
        }
        // Use noCalendarNames for items under calendar headers since it's redundant
        var calOpts = options
        calOpts.noCalendarNames = true
        for event in calGroups[calName]! {
            output.append(calOpts.bullet + formatEvent(event, options: calOpts))
        }
    }
    return output.joined(separator: "\n")
}

/// Format events as flat list
func formatEventsFlat(_ events: [EKEvent], options: ParsedOptions) -> String {
    var output: [String] = []
    for event in events {
        output.append(options.bullet + formatEvent(event, options: options))
    }
    return output.joined(separator: "\n")
}

/// Main formatting entry point
func formatEvents(_ events: [EKEvent], options: ParsedOptions) -> String {
    if events.isEmpty {
        return ""
    }
    if options.separateByDate {
        return formatEventsByDate(events, options: options)
    } else if options.separateByCalendar {
        return formatEventsByCalendar(events, options: options)
    } else {
        return formatEventsFlat(events, options: options)
    }
}
