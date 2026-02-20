import XCTest
@testable import CalBuddy

final class ArgumentParserTests: XCTestCase {

    func testEventsTodayCommand() {
        let opts = parseArguments(["eventsToday"])
        XCTAssertEqual(opts.command, .eventsToday)
    }

    func testEventsTodayPlusCommand() {
        let opts = parseArguments(["eventsToday+7"])
        XCTAssertEqual(opts.command, .eventsTodayPlus(7))
    }

    func testEventsNowCommand() {
        let opts = parseArguments(["eventsNow"])
        XCTAssertEqual(opts.command, .eventsNow)
    }

    func testCalendarsCommand() {
        let opts = parseArguments(["calendars"])
        XCTAssertEqual(opts.command, .calendars)
    }

    func testUncompletedTasksCommand() {
        let opts = parseArguments(["uncompletedTasks"])
        XCTAssertEqual(opts.command, .uncompletedTasks)
    }

    func testVersionCommand() {
        let opts = parseArguments(["-V"])
        XCTAssertEqual(opts.command, .version)
    }

    func testVersionLongFlag() {
        let opts = parseArguments(["--version"])
        XCTAssertEqual(opts.command, .version)
    }

    func testCompletionCommand() {
        let opts = parseArguments(["completion", "zsh"])
        XCTAssertEqual(opts.command, .completion("zsh"))
    }

    func testCompletionCommandWithoutShell() {
        let opts = parseArguments(["completion"])
        XCTAssertEqual(opts.command, .completion(""))
    }

    func testEventsFromToCommand() {
        let opts = parseArguments(["eventsFrom:2026-02-01", "to:2026-02-10"])
        XCTAssertEqual(opts.command, .eventsFromTo("2026-02-01", "2026-02-10"))
    }

    func testEventsFromToRelative() {
        let opts = parseArguments(["eventsFrom:today", "to:today+3"])
        XCTAssertEqual(opts.command, .eventsFromTo("today", "today+3"))
    }

    func testDateFormatShort() {
        let opts = parseArguments(["-df", "%Y/%m/%d", "eventsToday"])
        XCTAssertEqual(opts.dateFormat, "%Y/%m/%d")
        XCTAssertEqual(opts.command, .eventsToday)
    }

    func testDateFormatLong() {
        let opts = parseArguments(["--dateFormat", "%d.%m.%Y", "eventsToday"])
        XCTAssertEqual(opts.dateFormat, "%d.%m.%Y")
    }

    func testTimeFormatShort() {
        let opts = parseArguments(["-tf", "%I:%M %p", "eventsToday"])
        XCTAssertEqual(opts.timeFormat, "%I:%M %p")
    }

    func testIncludeCals() {
        let opts = parseArguments(["-ic", "Family,Work", "eventsToday"])
        XCTAssertEqual(opts.includeCals, ["Family", "Work"])
    }

    func testExcludeCals() {
        let opts = parseArguments(["--excludeCals", "Birthdays,Holidays", "eventsToday"])
        XCTAssertEqual(opts.excludeCals, ["Birthdays", "Holidays"])
    }

    func testSeparateByDate() {
        let opts = parseArguments(["-sd", "eventsToday"])
        XCTAssertTrue(opts.separateByDate)
    }

    func testSeparateByCalendar() {
        let opts = parseArguments(["--separateByCalendar", "eventsToday"])
        XCTAssertTrue(opts.separateByCalendar)
    }

    func testBulletShort() {
        let opts = parseArguments(["-b", "- ", "eventsToday"])
        XCTAssertEqual(opts.bullet, "- ")
    }

    func testNoCalendarNames() {
        let opts = parseArguments(["-nc", "eventsToday"])
        XCTAssertTrue(opts.noCalendarNames)
    }

    func testExcludeAllDayEvents() {
        let opts = parseArguments(["--excludeAllDayEvents", "eventsToday"])
        XCTAssertTrue(opts.excludeAllDayEvents)
    }

    func testIncludeOnlyFromNowOn() {
        let opts = parseArguments(["-n", "eventsToday"])
        XCTAssertTrue(opts.includeOnlyEventsFromNowOn)
    }

    func testExcludeEventProps() {
        let opts = parseArguments(["-eep", "location,notes", "eventsToday"])
        XCTAssertEqual(opts.excludeEventProps, Set(["location", "notes"]))
    }

    func testIncludeEventProps() {
        let opts = parseArguments(["--includeEventProps", "title,datetime", "eventsToday"])
        XCTAssertEqual(opts.includeEventProps, Set(["title", "datetime"]))
    }

    func testLimitItems() {
        let opts = parseArguments(["-li", "5", "eventsToday"])
        XCTAssertEqual(opts.limitItems, 5)
    }

    func testShowUIDs() {
        let opts = parseArguments(["--showUIDs", "eventsToday"])
        XCTAssertTrue(opts.showUIDs)
    }

    func testExcludeEndDates() {
        let opts = parseArguments(["-eed", "eventsToday"])
        XCTAssertTrue(opts.excludeEndDates)
    }

    func testShowEmptyDates() {
        let opts = parseArguments(["--showEmptyDates", "-sd", "eventsToday+3"])
        XCTAssertTrue(opts.showEmptyDates)
        XCTAssertTrue(opts.separateByDate)
    }

    func testFormatOutput() {
        let opts = parseArguments(["-f", "eventsToday"])
        XCTAssertTrue(opts.formatOutput)
    }

    func testJSONOutput() {
        let opts = parseArguments(["--json", "eventsToday"])
        XCTAssertEqual(opts.jsonMode, .compact)
        XCTAssertEqual(opts.command, .eventsToday)
    }

    func testJSONVerboseOutput() {
        let opts = parseArguments(["--json", "--verbose", "eventsToday"])
        XCTAssertEqual(opts.jsonMode, .verbose)
    }

    func testJSONEqualsAllAlias() {
        let opts = parseArguments(["--json=all", "eventsToday"])
        XCTAssertEqual(opts.jsonMode, .verbose)
    }

    func testMultipleFlags() {
        let opts = parseArguments(["-sd", "-nc", "-ea", "-f", "-li", "10", "-df", "%d/%m", "eventsToday+7"])
        XCTAssertTrue(opts.separateByDate)
        XCTAssertTrue(opts.noCalendarNames)
        XCTAssertTrue(opts.excludeAllDayEvents)
        XCTAssertTrue(opts.formatOutput)
        XCTAssertEqual(opts.limitItems, 10)
        XCTAssertEqual(opts.dateFormat, "%d/%m")
        XCTAssertEqual(opts.command, .eventsTodayPlus(7))
    }

    func testDefaultValues() {
        let opts = parseArguments(["eventsToday"])
        XCTAssertEqual(opts.dateFormat, "%Y-%m-%d %A")
        XCTAssertEqual(opts.timeFormat, "%H:%M")
        XCTAssertEqual(opts.bullet, "• ")
        XCTAssertFalse(opts.separateByCalendar)
        XCTAssertFalse(opts.separateByDate)
        XCTAssertFalse(opts.noCalendarNames)
        XCTAssertFalse(opts.excludeAllDayEvents)
        XCTAssertFalse(opts.includeOnlyEventsFromNowOn)
        XCTAssertFalse(opts.showUIDs)
        XCTAssertFalse(opts.excludeEndDates)
        XCTAssertFalse(opts.showEmptyDates)
        XCTAssertFalse(opts.formatOutput)
        XCTAssertNil(opts.jsonMode)
        XCTAssertNil(opts.limitItems)
        XCTAssertTrue(opts.includeCals.isEmpty)
        XCTAssertTrue(opts.excludeCals.isEmpty)
        XCTAssertTrue(opts.excludeEventProps.isEmpty)
        XCTAssertTrue(opts.includeEventProps.isEmpty)
    }

    func testHelpCommand() {
        let opts = parseArguments(["unknownCommand"])
        XCTAssertEqual(opts.command, .help)
    }

    func testNoArguments() {
        let opts = parseArguments([])
        XCTAssertEqual(opts.command, .help)
    }

    // MARK: - addEvent tests

    func testAddEventCommand() {
        let opts = parseArguments(["addEvent", "--title", "Dentist", "--calendar", "Family", "--start", "2026-02-10 14:00"])
        XCTAssertEqual(opts.command, .addEvent)
        XCTAssertEqual(opts.addEventOptions.title, "Dentist")
        XCTAssertEqual(opts.addEventOptions.calendarName, "Family")
        XCTAssertEqual(opts.addEventOptions.startString, "2026-02-10 14:00")
    }

    func testAddEventWithDuration() {
        let opts = parseArguments(["addEvent", "--title", "Meeting", "--calendar", "Work", "--start", "2026-02-10 09:00", "--duration", "30"])
        XCTAssertEqual(opts.command, .addEvent)
        XCTAssertEqual(opts.addEventOptions.duration, 30)
    }

    func testAddEventWithEnd() {
        let opts = parseArguments(["addEvent", "--title", "Meeting", "--calendar", "Work", "--start", "2026-02-10 09:00", "--end", "2026-02-10 10:30"])
        XCTAssertEqual(opts.addEventOptions.endString, "2026-02-10 10:30")
    }

    func testAddEventAllDay() {
        let opts = parseArguments(["addEvent", "--title", "Vacation", "--calendar", "Personal", "--start", "2026-02-10", "--allday"])
        XCTAssertEqual(opts.command, .addEvent)
        XCTAssertTrue(opts.addEventOptions.allDay)
    }

    func testAddEventWithAlarms() {
        let opts = parseArguments(["addEvent", "--title", "Call", "--calendar", "Family", "--start", "2026-02-10 09:00", "--alarm", "15", "--alarm", "60"])
        XCTAssertEqual(opts.addEventOptions.alarms, [15, 60])
    }

    func testAddEventWithAllOptional() {
        let opts = parseArguments([
            "addEvent",
            "--title", "Big Meeting",
            "--calendar", "Work",
            "--start", "2026-02-10 14:00",
            "--duration", "60",
            "--alarm", "15",
            "--location", "Conference Room",
            "--notes", "Bring laptop",
            "--url", "https://meet.example.com/123",
        ])
        XCTAssertEqual(opts.command, .addEvent)
        XCTAssertEqual(opts.addEventOptions.title, "Big Meeting")
        XCTAssertEqual(opts.addEventOptions.calendarName, "Work")
        XCTAssertEqual(opts.addEventOptions.startString, "2026-02-10 14:00")
        XCTAssertEqual(opts.addEventOptions.duration, 60)
        XCTAssertEqual(opts.addEventOptions.alarms, [15])
        XCTAssertEqual(opts.addEventOptions.location, "Conference Room")
        XCTAssertEqual(opts.addEventOptions.notes, "Bring laptop")
        XCTAssertEqual(opts.addEventOptions.url, "https://meet.example.com/123")
    }

    func testAddEventDefaultsEmpty() {
        let opts = parseArguments(["addEvent"])
        XCTAssertEqual(opts.command, .addEvent)
        XCTAssertEqual(opts.addEventOptions.title, "")
        XCTAssertEqual(opts.addEventOptions.calendarName, "")
        XCTAssertEqual(opts.addEventOptions.startString, "")
        XCTAssertNil(opts.addEventOptions.endString)
        XCTAssertNil(opts.addEventOptions.duration)
        XCTAssertFalse(opts.addEventOptions.allDay)
        XCTAssertTrue(opts.addEventOptions.alarms.isEmpty)
        XCTAssertNil(opts.addEventOptions.location)
        XCTAssertNil(opts.addEventOptions.notes)
        XCTAssertNil(opts.addEventOptions.url)
    }

    func testHelpMessageContainsLegacyCommandSyntax() {
        let help = helpMessage()
        XCTAssertTrue(help.contains("eventsFrom:START to:END"))
        XCTAssertTrue(help.contains("--dateFormat"))
    }

    func testCompletionScriptGenerationUsesParserSchema() {
        let zshScript = generateCompletionScript(for: "zsh")
        XCTAssertNotNil(zshScript)
        XCTAssertTrue(zshScript?.contains("calbuddy") == true)
        XCTAssertTrue(zshScript?.contains("--dateFormat") == true)
        XCTAssertTrue(zshScript?.contains("eventsToday") == true)
    }
}
