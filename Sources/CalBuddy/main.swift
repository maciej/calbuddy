import EventKit
import Foundation

let version = "1.0.0"

// Parse arguments (skip program name)
let args = Array(CommandLine.arguments.dropFirst())
let options = parseArguments(args)

switch options.command {
case .version:
    print("calbuddy \(version)")
    exit(0)

case .completion(let shell):
    guard let script = generateCompletionScript(for: shell) else {
        fputs("Error: completion requires one of: bash, zsh, fish\n", stderr)
        exit(1)
    }
    print(script)
    exit(0)

case .help:
    printHelp()
    exit(0)

case .calendars:
    let fetcher = EventFetcher()
    guard fetcher.requestCalendarAccess() else {
        fputs("Error: Calendar access denied. Grant access in System Settings > Privacy & Security > Calendars.\n", stderr)
        exit(1)
    }
    let calendars = fetcher.getAllCalendars()
    if let jsonMode = options.jsonMode {
        do {
            print(try formatCalendarsJSON(calendars, mode: jsonMode))
        } catch {
            fputs("Error: Failed to encode calendars JSON: \(error)\n", stderr)
            exit(1)
        }
    } else {
        let output = formatCalendars(calendars, formatOutput: options.formatOutput)
        if !output.isEmpty {
            print(output)
        }
    }
    exit(0)

case .uncompletedTasks:
    let fetcher = EventFetcher()
    guard fetcher.requestRemindersAccess() else {
        fputs("Error: Reminders access denied. Grant access in System Settings > Privacy & Security > Reminders.\n", stderr)
        exit(1)
    }
    let reminders = fetcher.fetchUncompletedReminders()
    let output = formatReminders(reminders, options: options)
    if !output.isEmpty {
        print(output)
    }
    exit(0)

case .eventsToday:
    let fetcher = EventFetcher()
    guard fetcher.requestCalendarAccess() else {
        fputs("Error: Calendar access denied. Grant access in System Settings > Privacy & Security > Calendars.\n", stderr)
        exit(1)
    }
    let cal = Calendar.current
    let startOfDay = cal.startOfDay(for: Date())
    let endOfDay = cal.date(byAdding: .day, value: 1, to: startOfDay)!
    let events = fetcher.fetchEvents(from: startOfDay, to: endOfDay, options: options)
    if let jsonMode = options.jsonMode {
        do {
            print(try formatEventsJSON(
                events: events,
                options: options,
                mode: jsonMode,
                command: "eventsToday",
                query: EventQueryMetadata(
                    startDate: startOfDay,
                    endDate: endOfDay,
                    startInput: "today",
                    endInput: "today+1",
                    referenceNow: nil
                )
            ))
        } catch {
            fputs("Error: Failed to encode events JSON: \(error)\n", stderr)
            exit(1)
        }
    } else {
        let output = formatEvents(events, options: options)
        if !output.isEmpty {
            print(output)
        }
    }
    exit(0)

case .eventsTodayPlus(let days):
    let fetcher = EventFetcher()
    guard fetcher.requestCalendarAccess() else {
        fputs("Error: Calendar access denied. Grant access in System Settings > Privacy & Security > Calendars.\n", stderr)
        exit(1)
    }
    let cal = Calendar.current
    let startOfDay = cal.startOfDay(for: Date())
    let endDate = cal.date(byAdding: .day, value: days + 1, to: startOfDay)!
    let events = fetcher.fetchEvents(from: startOfDay, to: endDate, options: options)
    if let jsonMode = options.jsonMode {
        do {
            print(try formatEventsJSON(
                events: events,
                options: options,
                mode: jsonMode,
                command: "eventsToday+\(days)",
                query: EventQueryMetadata(
                    startDate: startOfDay,
                    endDate: endDate,
                    startInput: "today",
                    endInput: "today+\(days + 1)",
                    referenceNow: nil
                )
            ))
        } catch {
            fputs("Error: Failed to encode events JSON: \(error)\n", stderr)
            exit(1)
        }
    } else {
        let output = formatEvents(events, options: options)
        if !output.isEmpty {
            print(output)
        }
    }
    exit(0)

case .eventsNow:
    let fetcher = EventFetcher()
    guard fetcher.requestCalendarAccess() else {
        fputs("Error: Calendar access denied. Grant access in System Settings > Privacy & Security > Calendars.\n", stderr)
        exit(1)
    }
    let now = Date()
    // Fetch events happening right now: started before now and ending after now
    let cal = Calendar.current
    let startOfDay = cal.startOfDay(for: now)
    let endOfDay = cal.date(byAdding: .day, value: 1, to: startOfDay)!
    var allEvents = fetcher.fetchEvents(from: startOfDay, to: endOfDay, options: options)
    allEvents = allEvents.filter { event in
        // Event is happening now if it started before now and ends after now
        event.startDate <= now && event.endDate > now
    }
    if let limit = options.limitItems, limit > 0 {
        allEvents = Array(allEvents.prefix(limit))
    }
    if let jsonMode = options.jsonMode {
        do {
            print(try formatEventsJSON(
                events: allEvents,
                options: options,
                mode: jsonMode,
                command: "eventsNow",
                query: EventQueryMetadata(
                    startDate: startOfDay,
                    endDate: endOfDay,
                    startInput: "today",
                    endInput: "today+1",
                    referenceNow: now
                )
            ))
        } catch {
            fputs("Error: Failed to encode events JSON: \(error)\n", stderr)
            exit(1)
        }
    } else {
        let output = formatEvents(allEvents, options: options)
        if !output.isEmpty {
            print(output)
        }
    }
    exit(0)

case .addEvent:
    let fetcher = EventFetcher()
    guard fetcher.requestCalendarAccess() else {
        fputs("Error: Calendar access denied. Grant access in System Settings > Privacy & Security > Calendars.\n", stderr)
        exit(1)
    }
    let creator = EventCreator(store: fetcher.store)
    do {
        let eventId = try creator.createEvent(options: options.addEventOptions)
        print("OK: \(eventId)")
        exit(0)
    } catch {
        fputs("Error: \(error)\n", stderr)
        exit(1)
    }

case .editEvent:
    let fetcher = EventFetcher()
    guard fetcher.requestCalendarAccess() else {
        fputs("Error: Calendar access denied. Grant access in System Settings > Privacy & Security > Calendars.\n", stderr)
        exit(1)
    }
    guard !options.editEventOptions.uid.isEmpty else {
        fputs("Error: --uid is required for editEvent\n", stderr)
        exit(1)
    }
    let editor = EventEditor(store: fetcher.store)
    do {
        let eventId = try editor.editEvent(options: options.editEventOptions)
        print("OK: \(eventId)")
        exit(0)
    } catch {
        fputs("Error: \(error)\n", stderr)
        exit(1)
    }

case .eventsFromTo(let startStr, let endStr):
    let fetcher = EventFetcher()
    guard fetcher.requestCalendarAccess() else {
        fputs("Error: Calendar access denied. Grant access in System Settings > Privacy & Security > Calendars.\n", stderr)
        exit(1)
    }
    guard let startDate = parseDateString(startStr) else {
        fputs("Error: Could not parse start date: \(startStr)\n", stderr)
        exit(1)
    }
    guard var endDate = parseDateString(endStr) else {
        fputs("Error: Could not parse end date: \(endStr)\n", stderr)
        exit(1)
    }
    // If end date is just a day (no time component), extend to end of that day
    let cal = Calendar.current
    if cal.startOfDay(for: endDate) == endDate {
        endDate = cal.date(byAdding: .day, value: 1, to: endDate)!
    }
    let events = fetcher.fetchEvents(from: startDate, to: endDate, options: options)
    if let jsonMode = options.jsonMode {
        do {
            print(try formatEventsJSON(
                events: events,
                options: options,
                mode: jsonMode,
                command: "eventsFrom",
                query: EventQueryMetadata(
                    startDate: startDate,
                    endDate: endDate,
                    startInput: startStr,
                    endInput: endStr,
                    referenceNow: nil
                )
            ))
        } catch {
            fputs("Error: Failed to encode events JSON: \(error)\n", stderr)
            exit(1)
        }
    } else {
        let output = formatEvents(events, options: options)
        if !output.isEmpty {
            print(output)
        }
    }
    exit(0)
}
