import EventKit
import Foundation

struct CommandResult: Equatable, Sendable {
    var stdout: String
    var stderr: String
    var exitCode: Int

    static let success = CommandResult(stdout: "", stderr: "", exitCode: 0)
}

protocol CommandRunning {
    func run(options: ParsedOptions) -> CommandResult
}

final class DirectCommandRunner: CommandRunning {
    private let fetcher: EventFetcher
    private var hasCalendarAccess = false

    init(fetcher: EventFetcher = EventFetcher(), hasCalendarAccess: Bool = false) {
        self.fetcher = fetcher
        self.hasCalendarAccess = hasCalendarAccess
    }

    func run(options: ParsedOptions) -> CommandResult {
        switch options.command {
        case .version:
            return output("calbuddy \(version)")

        case .completion(let shell):
            guard let script = generateCompletionScript(for: shell) else {
                return failure("Error: completion requires one of: bash, zsh, fish")
            }
            return output(script)

        case .help:
            return output(helpMessage())

        case .serve:
            return failure("Error: serve must be run by the top-level dispatcher")

        case .calendars:
            guard ensureCalendarAccess() else {
                return calendarAccessDenied()
            }
            let calendars = fetcher.getAllCalendars()
            if let jsonMode = options.jsonMode {
                do {
                    return output(try formatCalendarsJSON(calendars, mode: jsonMode))
                } catch {
                    return failure("Error: Failed to encode calendars JSON: \(error)")
                }
            }
            return outputIfPresent(formatCalendars(calendars, formatOutput: options.formatOutput))

        case .eventsToday:
            guard ensureCalendarAccess() else {
                return calendarAccessDenied()
            }
            let cal = Calendar.current
            let startOfDay = cal.startOfDay(for: Date())
            let endOfDay = cal.date(byAdding: .day, value: 1, to: startOfDay)!
            let events = fetcher.fetchEvents(from: startOfDay, to: endOfDay, options: options)
            return formatEventsResult(
                events: events,
                options: options,
                command: "eventsToday",
                query: EventQueryMetadata(
                    startDate: startOfDay,
                    endDate: endOfDay,
                    startInput: "today",
                    endInput: "today+1",
                    referenceNow: nil
                )
            )

        case .eventsTodayPlus(let days):
            guard ensureCalendarAccess() else {
                return calendarAccessDenied()
            }
            let cal = Calendar.current
            let startOfDay = cal.startOfDay(for: Date())
            let endDate = cal.date(byAdding: .day, value: days + 1, to: startOfDay)!
            let events = fetcher.fetchEvents(from: startOfDay, to: endDate, options: options)
            return formatEventsResult(
                events: events,
                options: options,
                command: "eventsToday+\(days)",
                query: EventQueryMetadata(
                    startDate: startOfDay,
                    endDate: endDate,
                    startInput: "today",
                    endInput: "today+\(days + 1)",
                    referenceNow: nil
                )
            )

        case .eventsNow:
            guard ensureCalendarAccess() else {
                return calendarAccessDenied()
            }
            let now = Date()
            let cal = Calendar.current
            let startOfDay = cal.startOfDay(for: now)
            let endOfDay = cal.date(byAdding: .day, value: 1, to: startOfDay)!
            var events = fetcher.fetchEvents(from: startOfDay, to: endOfDay, options: options)
            events = events.filter { event in
                event.startDate <= now && event.endDate > now
            }
            if let limit = options.limitItems, limit > 0 {
                events = Array(events.prefix(limit))
            }
            return formatEventsResult(
                events: events,
                options: options,
                command: "eventsNow",
                query: EventQueryMetadata(
                    startDate: startOfDay,
                    endDate: endOfDay,
                    startInput: "today",
                    endInput: "today+1",
                    referenceNow: now
                )
            )

        case .addEvent:
            guard ensureCalendarAccess() else {
                return calendarAccessDenied()
            }
            let creator = EventCreator(store: fetcher.store)
            do {
                return output("OK: \(try creator.createEvent(options: options.addEventOptions))")
            } catch {
                return failure("Error: \(error)")
            }

        case .editEvent:
            guard ensureCalendarAccess() else {
                return calendarAccessDenied()
            }
            guard !options.editEventOptions.uid.isEmpty else {
                return failure("Error: --uid is required for editEvent")
            }
            let editor = EventEditor(store: fetcher.store)
            do {
                return output("OK: \(try editor.editEvent(options: options.editEventOptions))")
            } catch {
                return failure("Error: \(error)")
            }

        case .eventsFromTo(let startStr, let endStr):
            guard ensureCalendarAccess() else {
                return calendarAccessDenied()
            }
            guard let startDate = parseDateString(startStr) else {
                return failure("Error: Could not parse start date: \(startStr)")
            }
            guard var endDate = parseDateString(endStr) else {
                return failure("Error: Could not parse end date: \(endStr)")
            }
            let cal = Calendar.current
            if cal.startOfDay(for: endDate) == endDate {
                endDate = cal.date(byAdding: .day, value: 1, to: endDate)!
            }
            let events = fetcher.fetchEvents(from: startDate, to: endDate, options: options)
            return formatEventsResult(
                events: events,
                options: options,
                command: "eventsFrom",
                query: EventQueryMetadata(
                    startDate: startDate,
                    endDate: endDate,
                    startInput: startStr,
                    endInput: endStr,
                    referenceNow: nil
                )
            )
        }
    }

    private func ensureCalendarAccess() -> Bool {
        if hasCalendarAccess {
            return true
        }
        hasCalendarAccess = fetcher.requestCalendarAccess()
        return hasCalendarAccess
    }

    private func formatEventsResult(
        events: [EKEvent],
        options: ParsedOptions,
        command: String,
        query: EventQueryMetadata
    ) -> CommandResult {
        if let jsonMode = options.jsonMode {
            do {
                return output(try formatEventsJSON(
                    events: events,
                    options: options,
                    mode: jsonMode,
                    command: command,
                    query: query
                ))
            } catch {
                return failure("Error: Failed to encode events JSON: \(error)")
            }
        }
        return outputIfPresent(formatEvents(events, options: options))
    }
}

private func output(_ text: String) -> CommandResult {
    CommandResult(stdout: text + "\n", stderr: "", exitCode: 0)
}

private func outputIfPresent(_ text: String) -> CommandResult {
    text.isEmpty ? .success : output(text)
}

private func failure(_ text: String) -> CommandResult {
    CommandResult(stdout: "", stderr: text + "\n", exitCode: 1)
}

private func calendarAccessDenied() -> CommandResult {
    failure("Error: Calendar access denied. Grant access in System Settings > Privacy & Security > Calendars.")
}
