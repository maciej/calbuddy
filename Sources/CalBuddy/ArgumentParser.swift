import ArgumentParser
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

private let legacyCommandCompletions = [
    "eventsToday",
    "eventsToday+1",
    "eventsNow",
    "eventsFrom:today",
    "calendars",
    "uncompletedTasks",
    "addEvent",
    "editEvent",
    "completion",
    "completions",
]

struct CalBuddyCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "calbuddy",
        abstract: "A modern replacement for icalBuddy, built with Swift and EventKit.",
        discussion: """
        Legacy-compatible commands:
          eventsToday
          eventsToday+N
          eventsNow
          eventsFrom:START to:END
          calendars
          uncompletedTasks
          addEvent
          editEvent
          completion SHELL
        """
    )

    @Option(
        name: [.customLong("df", withSingleDash: true), .customLong("dateFormat")],
        help: ArgumentHelp("Date format", valueName: "FORMAT")
    )
    var dateFormat: String = "%Y-%m-%d %A"

    @Option(
        name: [.customLong("tf", withSingleDash: true), .customLong("timeFormat")],
        help: ArgumentHelp("Time format", valueName: "FORMAT")
    )
    var timeFormat: String = "%H:%M"

    @Option(
        name: [.customLong("ic", withSingleDash: true), .customLong("includeCals")],
        help: ArgumentHelp("Include only these calendars (comma-separated)", valueName: "CALS")
    )
    var includeCalsRaw: String?

    @Option(
        name: [.customLong("ec", withSingleDash: true), .customLong("excludeCals")],
        help: ArgumentHelp("Exclude these calendars (comma-separated)", valueName: "CALS")
    )
    var excludeCalsRaw: String?

    @Flag(
        name: [.customLong("sc", withSingleDash: true), .customLong("separateByCalendar")],
        help: "Group output by calendar"
    )
    var separateByCalendar: Bool = false

    @Flag(
        name: [.customLong("sd", withSingleDash: true), .customLong("separateByDate")],
        help: "Group output by date"
    )
    var separateByDate: Bool = false

    @Option(
        name: [.customShort("b"), .customLong("bullet")],
        parsing: .unconditional,
        help: ArgumentHelp("Bullet prefix", valueName: "VALUE")
    )
    var bullet: String = "• "

    @Flag(
        name: [.customLong("nc", withSingleDash: true), .customLong("noCalendarNames")],
        help: "Hide calendar names"
    )
    var noCalendarNames: Bool = false

    @Flag(
        name: [.customLong("ea", withSingleDash: true), .customLong("excludeAllDayEvents")],
        help: "Skip all-day events"
    )
    var excludeAllDayEvents: Bool = false

    @Flag(
        name: [.customShort("n"), .customLong("includeOnlyEventsFromNowOn")],
        help: "Only include future events"
    )
    var includeOnlyEventsFromNowOn: Bool = false

    @Option(
        name: [.customLong("eep", withSingleDash: true), .customLong("excludeEventProps")],
        help: ArgumentHelp("Exclude properties", valueName: "PROPS")
    )
    var excludeEventPropsRaw: String?

    @Option(
        name: [.customLong("iep", withSingleDash: true), .customLong("includeEventProps")],
        help: ArgumentHelp("Include only these properties", valueName: "PROPS")
    )
    var includeEventPropsRaw: String?

    @Option(
        name: [.customLong("li", withSingleDash: true), .customLong("limitItems")],
        help: ArgumentHelp("Max items", valueName: "NUM")
    )
    var limitItemsRaw: String?

    @Flag(
        name: [.customLong("uid", withSingleDash: true), .customLong("showUIDs")],
        help: "Show event UIDs"
    )
    var showUIDs: Bool = false

    @Flag(
        name: [.customLong("eed", withSingleDash: true), .customLong("excludeEndDates")],
        help: "Hide end dates"
    )
    var excludeEndDates: Bool = false

    @Flag(
        name: [.customLong("sed", withSingleDash: true), .customLong("showEmptyDates")],
        help: "Show empty date sections"
    )
    var showEmptyDates: Bool = false

    @Flag(
        name: [.customShort("f"), .customLong("formatOutput")],
        help: "ANSI color formatting"
    )
    var formatOutput: Bool = false

    @Flag(
        name: [.customShort("V"), .customLong("version")],
        help: "Print version"
    )
    var versionRequested: Bool = false

    @Option(name: .customLong("title"), help: ArgumentHelp("Event title", valueName: "TITLE"))
    var title: String?

    @Option(name: .customLong("calendar"), help: ArgumentHelp("Calendar name", valueName: "NAME"))
    var calendarName: String?

    @Option(name: .customLong("start"), help: ArgumentHelp("Start date/time", valueName: "DATETIME"))
    var startString: String?

    @Option(name: .customLong("end"), help: ArgumentHelp("End date/time", valueName: "DATETIME"))
    var endString: String?

    @Option(name: .customLong("duration"), help: ArgumentHelp("Duration in minutes", valueName: "MINUTES"))
    var durationRaw: String?

    @Flag(name: .customLong("allday"), help: "Create/set all-day event")
    var allDay: Bool = false

    @Option(name: .customLong("alarm"), help: ArgumentHelp("Alarm minutes before", valueName: "MINUTES"))
    var alarmValues: [String] = []

    @Option(name: .customLong("location"), help: ArgumentHelp("Event location", valueName: "PLACE"))
    var location: String?

    @Option(name: .customLong("notes"), help: ArgumentHelp("Event notes", valueName: "TEXT"))
    var notes: String?

    @Option(name: .customLong("url"), help: ArgumentHelp("Event URL", valueName: "URL"))
    var url: String?

    @Option(name: .customLong("uid"), help: ArgumentHelp("Event UID for editEvent", valueName: "UID"))
    var eventUID: String?

    @Argument(help: "Legacy command token(s)", completion: .list(legacyCommandCompletions))
    var positionals: [String] = []
}

private func splitCSV(_ raw: String?) -> [String] {
    guard let raw, !raw.isEmpty else { return [] }
    return raw.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
}

private func parseCommand(positionals: [String]) -> Command {
    guard let commandToken = positionals.first else {
        return .help
    }

    if commandToken == "eventsToday" {
        return .eventsToday
    }
    if commandToken.hasPrefix("eventsToday+") {
        let numStr = String(commandToken.dropFirst("eventsToday+".count))
        if let n = Int(numStr) {
            return .eventsTodayPlus(n)
        }
        return .eventsToday
    }
    if commandToken == "eventsNow" {
        return .eventsNow
    }
    if commandToken.hasPrefix("eventsFrom:") {
        let start = String(commandToken.dropFirst("eventsFrom:".count))
        let end = positionals.dropFirst().first { $0.hasPrefix("to:") }
            .map { String($0.dropFirst("to:".count)) } ?? start
        return .eventsFromTo(start, end)
    }
    if commandToken == "calendars" {
        return .calendars
    }
    if commandToken == "uncompletedTasks" {
        return .uncompletedTasks
    }
    if commandToken == "addEvent" {
        return .addEvent
    }
    if commandToken == "editEvent" {
        return .editEvent
    }
    if commandToken == "completion" || commandToken == "completions" {
        if let shell = positionals.dropFirst().first?.lowercased(),
           shell == "bash" || shell == "zsh" || shell == "fish"
        {
            return .completion(shell)
        }
        return .completion("")
    }
    return .help
}

private extension CalBuddyCLI {
    func toParsedOptions() -> ParsedOptions {
        var opts = ParsedOptions()

        opts.dateFormat = dateFormat
        opts.timeFormat = timeFormat
        opts.includeCals = splitCSV(includeCalsRaw)
        opts.excludeCals = splitCSV(excludeCalsRaw)
        opts.separateByCalendar = separateByCalendar
        opts.separateByDate = separateByDate
        opts.bullet = bullet
        opts.noCalendarNames = noCalendarNames
        opts.excludeAllDayEvents = excludeAllDayEvents
        opts.includeOnlyEventsFromNowOn = includeOnlyEventsFromNowOn
        opts.excludeEventProps = Set(splitCSV(excludeEventPropsRaw))
        opts.includeEventProps = Set(splitCSV(includeEventPropsRaw))
        opts.limitItems = limitItemsRaw.flatMap(Int.init)
        opts.showUIDs = showUIDs
        opts.excludeEndDates = excludeEndDates
        opts.showEmptyDates = showEmptyDates
        opts.formatOutput = formatOutput

        opts.addEventOptions.title = title ?? ""
        opts.addEventOptions.calendarName = calendarName ?? ""
        opts.addEventOptions.startString = startString ?? ""
        opts.addEventOptions.endString = endString
        opts.addEventOptions.duration = durationRaw.flatMap(Int.init)
        opts.addEventOptions.allDay = allDay
        opts.addEventOptions.alarms = alarmValues.compactMap(Int.init)
        opts.addEventOptions.location = location
        opts.addEventOptions.notes = notes
        opts.addEventOptions.url = url

        opts.editEventOptions.uid = eventUID ?? ""

        opts.command = parseCommand(positionals: positionals)
        if versionRequested {
            opts.command = .version
        }

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
}

/// Parse command-line arguments into ParsedOptions
func parseArguments(_ args: [String]) -> ParsedOptions {
    do {
        let parsed = try CalBuddyCLI.parse(args)
        return parsed.toParsedOptions()
    } catch {
        return ParsedOptions()
    }
}

func helpMessage() -> String {
    CalBuddyCLI.helpMessage()
}

/// Print help/usage
func printHelp() {
    print(helpMessage())
}
