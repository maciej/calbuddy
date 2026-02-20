import Foundation

/// Represents the command the user wants to execute
enum Command: Equatable, Sendable {
    case eventsToday
    case eventsTodayPlus(Int)
    case eventsNow
    case eventsFromTo(String, String)
    case calendars
    case uncompletedTasks
    case addEvent
    case editEvent
    case completion(String)
    case version
    case help
}

/// Options specific to the addEvent command
struct AddEventOptions: Sendable, Equatable {
    var title: String = ""
    var calendarName: String = ""
    var startString: String = ""
    var endString: String? = nil
    var duration: Int? = nil
    var allDay: Bool = false
    var alarms: [Int] = []
    var location: String? = nil
    var notes: String? = nil
    var url: String? = nil
}

/// Options specific to the editEvent command
struct EditEventOptions: Sendable, Equatable {
    var uid: String = ""
    var title: String? = nil
    var startString: String? = nil
    var endString: String? = nil
    var duration: Int? = nil
    var allDay: Bool? = nil
    var alarms: [Int]? = nil
    var location: String? = nil
    var notes: String? = nil
    var url: String? = nil
}

/// All parsed options from command line
struct ParsedOptions: Sendable {
    var command: Command = .help
    var dateFormat: String = "%Y-%m-%d %A"
    var timeFormat: String = "%H:%M"
    var includeCals: [String] = []
    var excludeCals: [String] = []
    var separateByCalendar: Bool = false
    var separateByDate: Bool = false
    var bullet: String = "• "
    var noCalendarNames: Bool = false
    var excludeAllDayEvents: Bool = false
    var includeOnlyEventsFromNowOn: Bool = false
    var excludeEventProps: Set<String> = []
    var includeEventProps: Set<String> = []
    var limitItems: Int? = nil
    var showUIDs: Bool = false
    var excludeEndDates: Bool = false
    var showEmptyDates: Bool = false
    var formatOutput: Bool = false
    var addEventOptions: AddEventOptions = AddEventOptions()
    var editEventOptions: EditEventOptions = EditEventOptions()
}

/// Parse command-line arguments into ParsedOptions
func parseArguments(_ args: [String]) -> ParsedOptions {
    var opts = ParsedOptions()
    var i = 0

    // First, find the command (first non-flag argument)
    var commandFound = false
    var commandIndex = -1

    // Scan for command
    var scanIdx = 0
    while scanIdx < args.count {
        let arg = args[scanIdx]
        if arg == "-V" || arg == "--version" {
            opts.command = .version
            commandFound = true
            scanIdx += 1
            continue
        }
        if arg.hasPrefix("-") {
            // It's a flag, skip it and its value if applicable
            let flagsWithValues: Set<String> = [
                "-df", "--dateFormat",
                "-tf", "--timeFormat",
                "-ic", "--includeCals",
                "-ec", "--excludeCals",
                "-b", "--bullet",
                "-eep", "--excludeEventProps",
                "-iep", "--includeEventProps",
                "-li", "--limitItems",
                "--title", "--calendar", "--start", "--end",
                "--duration", "--alarm", "--location", "--notes", "--url",
                "--uid",
            ]
            if flagsWithValues.contains(arg) {
                scanIdx += 2  // skip flag + value
            } else {
                scanIdx += 1  // boolean flag
            }
            continue
        }
        // It's a positional argument — treat as command
        if !commandFound {
            commandIndex = scanIdx
            commandFound = true
        }
        scanIdx += 1
    }

    // Parse the command
    if commandIndex >= 0 {
        let cmdStr = args[commandIndex]
        opts.command = parseCommand(cmdStr, args: args, startIndex: commandIndex)
    }

    // Now parse all flags
    i = 0
    while i < args.count {
        let arg = args[i]

        switch arg {
        case "-df", "--dateFormat":
            if i + 1 < args.count {
                opts.dateFormat = args[i + 1]
                i += 2
            } else { i += 1 }

        case "-tf", "--timeFormat":
            if i + 1 < args.count {
                opts.timeFormat = args[i + 1]
                i += 2
            } else { i += 1 }

        case "-ic", "--includeCals":
            if i + 1 < args.count {
                opts.includeCals = args[i + 1].split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
                i += 2
            } else { i += 1 }

        case "-ec", "--excludeCals":
            if i + 1 < args.count {
                opts.excludeCals = args[i + 1].split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
                i += 2
            } else { i += 1 }

        case "-sc", "--separateByCalendar":
            opts.separateByCalendar = true
            i += 1

        case "-sd", "--separateByDate":
            opts.separateByDate = true
            i += 1

        case "-b", "--bullet":
            if i + 1 < args.count {
                opts.bullet = args[i + 1]
                i += 2
            } else { i += 1 }

        case "-nc", "--noCalendarNames":
            opts.noCalendarNames = true
            i += 1

        case "-ea", "--excludeAllDayEvents":
            opts.excludeAllDayEvents = true
            i += 1

        case "-n", "--includeOnlyEventsFromNowOn":
            opts.includeOnlyEventsFromNowOn = true
            i += 1

        case "-eep", "--excludeEventProps":
            if i + 1 < args.count {
                opts.excludeEventProps = Set(args[i + 1].split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) })
                i += 2
            } else { i += 1 }

        case "-iep", "--includeEventProps":
            if i + 1 < args.count {
                opts.includeEventProps = Set(args[i + 1].split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) })
                i += 2
            } else { i += 1 }

        case "-li", "--limitItems":
            if i + 1 < args.count {
                opts.limitItems = Int(args[i + 1])
                i += 2
            } else { i += 1 }

        case "-uid", "--showUIDs":
            opts.showUIDs = true
            i += 1

        case "-eed", "--excludeEndDates":
            opts.excludeEndDates = true
            i += 1

        case "-sed", "--showEmptyDates":
            opts.showEmptyDates = true
            i += 1

        case "-f", "--formatOutput":
            opts.formatOutput = true
            i += 1

        case "-V", "--version":
            // Already handled
            i += 1

        // addEvent flags
        case "--title":
            if i + 1 < args.count {
                opts.addEventOptions.title = args[i + 1]
                i += 2
            } else { i += 1 }

        case "--calendar":
            if i + 1 < args.count {
                opts.addEventOptions.calendarName = args[i + 1]
                i += 2
            } else { i += 1 }

        case "--start":
            if i + 1 < args.count {
                opts.addEventOptions.startString = args[i + 1]
                i += 2
            } else { i += 1 }

        case "--end":
            if i + 1 < args.count {
                opts.addEventOptions.endString = args[i + 1]
                i += 2
            } else { i += 1 }

        case "--duration":
            if i + 1 < args.count {
                opts.addEventOptions.duration = Int(args[i + 1])
                i += 2
            } else { i += 1 }

        case "--allday":
            opts.addEventOptions.allDay = true
            i += 1

        case "--alarm":
            if i + 1 < args.count {
                if let minutes = Int(args[i + 1]) {
                    opts.addEventOptions.alarms.append(minutes)
                }
                i += 2
            } else { i += 1 }

        case "--location":
            if i + 1 < args.count {
                opts.addEventOptions.location = args[i + 1]
                i += 2
            } else { i += 1 }

        case "--notes":
            if i + 1 < args.count {
                opts.addEventOptions.notes = args[i + 1]
                i += 2
            } else { i += 1 }

        case "--url":
            if i + 1 < args.count {
                opts.addEventOptions.url = args[i + 1]
                i += 2
            } else { i += 1 }

        case "--uid":
            if i + 1 < args.count {
                opts.editEventOptions.uid = args[i + 1]
                i += 2
            } else { i += 1 }

        default:
            i += 1
        }
    }

    // Populate editEventOptions from shared flags when editEvent command
    if opts.command == .editEvent {
        let add = opts.addEventOptions
        if !add.title.isEmpty { opts.editEventOptions.title = add.title }
        if !add.startString.isEmpty { opts.editEventOptions.startString = add.startString }
        if let e = add.endString { opts.editEventOptions.endString = e }
        if let d = add.duration { opts.editEventOptions.duration = d }
        if add.allDay { opts.editEventOptions.allDay = true }
        if !add.alarms.isEmpty { opts.editEventOptions.alarms = add.alarms }
        if let l = add.location { opts.editEventOptions.location = l }
        if let n = add.notes { opts.editEventOptions.notes = n }
        if let u = add.url { opts.editEventOptions.url = u }
    }

    return opts
}

/// Parse a command string into a Command enum
func parseCommand(_ cmd: String, args: [String], startIndex: Int) -> Command {
    if cmd == "eventsToday" {
        return .eventsToday
    } else if cmd.hasPrefix("eventsToday+") {
        let numStr = String(cmd.dropFirst("eventsToday+".count))
        if let n = Int(numStr) {
            return .eventsTodayPlus(n)
        }
        return .eventsToday
    } else if cmd == "eventsNow" {
        return .eventsNow
    } else if cmd.hasPrefix("eventsFrom:") {
        // Parse eventsFrom:START to:END
        let startStr = String(cmd.dropFirst("eventsFrom:".count))
        var endStr = ""
        // Look for "to:END" in subsequent args
        var j = startIndex + 1
        while j < args.count {
            if args[j].hasPrefix("to:") {
                endStr = String(args[j].dropFirst("to:".count))
                break
            }
            j += 1
        }
        if endStr.isEmpty {
            endStr = startStr  // fallback
        }
        return .eventsFromTo(startStr, endStr)
    } else if cmd == "calendars" {
        return .calendars
    } else if cmd == "uncompletedTasks" {
        return .uncompletedTasks
    } else if cmd == "addEvent" {
        return .addEvent
    } else if cmd == "editEvent" {
        return .editEvent
    } else if cmd == "completion" || cmd == "completions" {
        if startIndex + 1 < args.count {
            let shell = args[startIndex + 1].lowercased()
            if shell == "bash" || shell == "zsh" || shell == "fish" {
                return .completion(shell)
            }
        }
        return .completion("")
    } else {
        return .help
    }
}

/// Print help/usage
func printHelp() {
    let help = """
    calbuddy - A modern icalBuddy replacement using EventKit

    USAGE:
        calbuddy [options] <command>

    COMMANDS:
        eventsToday          Events occurring today
        eventsToday+N        Events from today through N days ahead
        eventsNow            Events occurring right now
        eventsFrom:START to:END  Events in date range
        calendars            List all calendars
        uncompletedTasks     Print uncompleted reminders
        addEvent             Create a new calendar event
        editEvent            Edit an existing event by UID
        completion SHELL     Print shell completion script (bash|zsh|fish)

    OPTIONS:
        -df, --dateFormat FORMAT       Date format (default: %Y-%m-%d %A)
        -tf, --timeFormat FORMAT       Time format (default: %H:%M)
        -ic, --includeCals CALS        Include only these calendars (comma-separated)
        -ec, --excludeCals CALS        Exclude these calendars (comma-separated)
        -sc, --separateByCalendar      Group output by calendar
        -sd, --separateByDate          Group output by date
        -b,  --bullet VALUE            Bullet string (default: "• ")
        -nc, --noCalendarNames         Omit calendar names
        -ea, --excludeAllDayEvents     Skip all-day events
        -n,  --includeOnlyEventsFromNowOn  Only future events
        -eep, --excludeEventProps PROPS  Exclude properties
        -iep, --includeEventProps PROPS  Include only these properties
        -li, --limitItems NUM          Max items to print
        -uid, --showUIDs               Show event UIDs
        -eed, --excludeEndDates        Don't show end times
        -sed, --showEmptyDates         Show empty date sections
        -f,  --formatOutput            ANSI color formatting
        -V,  --version                 Print version

    ADDEVENT OPTIONS:
        --title TITLE          Event title (required)
        --calendar NAME        Calendar name (required)
        --start DATETIME       Start date/time "YYYY-MM-DD HH:MM" (required)
        --end DATETIME         End date/time (default: start + 1 hour)
        --duration MINUTES     Duration in minutes (alternative to --end)
        --allday               Create as all-day event
        --alarm MINUTES        Alarm N minutes before (repeatable)
        --location PLACE       Event location
        --notes TEXT           Event notes
        --url URL              Event URL

    EDITEVENT OPTIONS:
        --uid UID              Event UID from -uid output (required)
        --title TITLE          New title
        --start DATETIME       New start date/time
        --end DATETIME         New end date/time
        --duration MINUTES     New duration
        --allday               Set as all-day event
        --alarm MINUTES        Replace alarms (repeatable)
        --location PLACE       New location
        --notes TEXT           New notes
        --url URL              New URL

    PROPERTIES: title, datetime, location, notes, url, attendees
    """
    print(help)
}
