import XCTest
@testable import CalBuddy

final class EventFormatterTests: XCTestCase {

    // MARK: - strftime conversion tests

    func testStrftimeYear() {
        XCTAssertEqual(strftimeToDateFormat("%Y"), "yyyy")
    }

    func testStrftimeMonth() {
        XCTAssertEqual(strftimeToDateFormat("%m"), "MM")
    }

    func testStrftimeDay() {
        XCTAssertEqual(strftimeToDateFormat("%d"), "dd")
    }

    func testStrftimeHour24() {
        XCTAssertEqual(strftimeToDateFormat("%H"), "HH")
    }

    func testStrftimeHour12() {
        XCTAssertEqual(strftimeToDateFormat("%I"), "hh")
    }

    func testStrftimeMinute() {
        XCTAssertEqual(strftimeToDateFormat("%M"), "mm")
    }

    func testStrftimeSecond() {
        XCTAssertEqual(strftimeToDateFormat("%S"), "ss")
    }

    func testStrftimeWeekdayFull() {
        XCTAssertEqual(strftimeToDateFormat("%A"), "EEEE")
    }

    func testStrftimeWeekdayShort() {
        XCTAssertEqual(strftimeToDateFormat("%a"), "EEE")
    }

    func testStrftimeDefaultDateFormat() {
        XCTAssertEqual(strftimeToDateFormat("%Y-%m-%d %A"), "yyyy-MM-dd EEEE")
    }

    func testStrftimeDefaultTimeFormat() {
        XCTAssertEqual(strftimeToDateFormat("%H:%M"), "HH:mm")
    }

    func testStrftimePercent() {
        XCTAssertEqual(strftimeToDateFormat("%%"), "%")
    }

    func testStrftimeComplexFormat() {
        XCTAssertEqual(strftimeToDateFormat("%d/%m/%Y"), "dd/MM/yyyy")
    }

    // MARK: - formatDate tests

    func testFormatDateBasic() {
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 2
        comps.day = 4
        comps.hour = 13
        comps.minute = 30
        let date = Calendar.current.date(from: comps)!

        let result = formatDate(date, format: "%H:%M")
        XCTAssertEqual(result, "13:30")
    }

    func testFormatDateDay() {
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 2
        comps.day = 4
        let date = Calendar.current.date(from: comps)!

        let result = formatDate(date, format: "%Y-%m-%d")
        XCTAssertEqual(result, "2026-02-04")
    }

    // MARK: - shouldShowProperty tests

    func testShouldShowPropertyDefault() {
        let opts = ParsedOptions()
        XCTAssertTrue(shouldShowProperty("title", options: opts))
        XCTAssertTrue(shouldShowProperty("location", options: opts))
    }

    func testShouldShowPropertyExclude() {
        var opts = ParsedOptions()
        opts.excludeEventProps = Set(["location", "notes"])
        XCTAssertTrue(shouldShowProperty("title", options: opts))
        XCTAssertFalse(shouldShowProperty("location", options: opts))
        XCTAssertFalse(shouldShowProperty("notes", options: opts))
    }

    func testShouldShowPropertyInclude() {
        var opts = ParsedOptions()
        opts.includeEventProps = Set(["title", "datetime"])
        XCTAssertTrue(shouldShowProperty("title", options: opts))
        XCTAssertTrue(shouldShowProperty("datetime", options: opts))
        XCTAssertFalse(shouldShowProperty("location", options: opts))
    }

    // MARK: - parseDateString tests

    func testParseDateStringISO() {
        let date = parseDateString("2026-02-04")
        XCTAssertNotNil(date)
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: date!)
        XCTAssertEqual(comps.year, 2026)
        XCTAssertEqual(comps.month, 2)
        XCTAssertEqual(comps.day, 4)
    }

    func testParseDateStringFull() {
        let date = parseDateString("2026-02-04 13:30:00")
        XCTAssertNotNil(date)
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date!)
        XCTAssertEqual(comps.hour, 13)
        XCTAssertEqual(comps.minute, 30)
    }

    func testParseDateStringToday() {
        let date = parseDateString("today")
        XCTAssertNotNil(date)
        XCTAssertEqual(date, Calendar.current.startOfDay(for: Date()))
    }

    func testParseDateStringTodayPlus() {
        let date = parseDateString("today+3")
        XCTAssertNotNil(date)
        let expected = Calendar.current.date(byAdding: .day, value: 3, to: Calendar.current.startOfDay(for: Date()))
        XCTAssertEqual(date, expected)
    }

    func testParseDateStringInvalid() {
        let date = parseDateString("not-a-date")
        XCTAssertNil(date)
    }
}
