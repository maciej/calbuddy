import XCTest
@testable import CalBuddy

final class ClientDispatcherTests: XCTestCase {
    func testReadActionUsesServerWhenAvailable() {
        let serverResult = CommandResult(stdout: "server events\n", stderr: "", exitCode: 0)
        let directRunner = FakeRunner(result: CommandResult(stdout: "direct events\n", stderr: "", exitCode: 0))
        let transport = FakeTransport(result: .success(serverResult))
        let options = parseArguments(["eventsToday"], environment: [:])

        let result = dispatchClientCommand(
            rawArguments: ["eventsToday"],
            options: options,
            directRunner: directRunner,
            serverClient: transport
        )

        XCTAssertEqual(result, serverResult)
        XCTAssertEqual(transport.sentArgv, [["eventsToday"]])
        XCTAssertEqual(directRunner.runCount, 0)
    }

    func testMutatingActionUsesServerWhenAvailable() {
        let serverResult = CommandResult(stdout: "OK: event-1\n", stderr: "", exitCode: 0)
        let directRunner = FakeRunner(result: CommandResult(stdout: "OK: direct\n", stderr: "", exitCode: 0))
        let transport = FakeTransport(result: .success(serverResult))
        let raw = ["addEvent", "--title", "Dentist", "--calendar", "Family", "--start", "2026-02-10 14:00"]
        let options = parseArguments(raw, environment: [:])

        let result = dispatchClientCommand(
            rawArguments: raw,
            options: options,
            directRunner: directRunner,
            serverClient: transport
        )

        XCTAssertEqual(result, serverResult)
        XCTAssertEqual(transport.sentArgv, [raw])
        XCTAssertEqual(directRunner.runCount, 0)
    }

    func testUnavailableServerFallsBackToDirectRunner() {
        let directResult = CommandResult(stdout: "direct events\n", stderr: "", exitCode: 0)
        let directRunner = FakeRunner(result: directResult)
        let transport = FakeTransport(result: .failure(.unavailable("missing socket")))
        let options = parseArguments(["eventsToday"], environment: [:])

        let result = dispatchClientCommand(
            rawArguments: ["eventsToday"],
            options: options,
            directRunner: directRunner,
            serverClient: transport
        )

        XCTAssertEqual(result, directResult)
        XCTAssertEqual(transport.sentArgv, [["eventsToday"]])
        XCTAssertEqual(directRunner.runCount, 1)
    }

    func testServerCommandErrorDoesNotFallBack() {
        let serverResult = CommandResult(stdout: "", stderr: "Error: Calendar failed\n", exitCode: 1)
        let directRunner = FakeRunner(result: CommandResult(stdout: "direct\n", stderr: "", exitCode: 0))
        let transport = FakeTransport(result: .success(serverResult))
        let options = parseArguments(["eventsToday"], environment: [:])

        let result = dispatchClientCommand(
            rawArguments: ["eventsToday"],
            options: options,
            directRunner: directRunner,
            serverClient: transport
        )

        XCTAssertEqual(result, serverResult)
        XCTAssertEqual(directRunner.runCount, 0)
    }

    func testDirectFlagSkipsTransport() {
        let directResult = CommandResult(stdout: "direct events\n", stderr: "", exitCode: 0)
        let directRunner = FakeRunner(result: directResult)
        let transport = FakeTransport(result: .success(CommandResult(stdout: "server\n", stderr: "", exitCode: 0)))
        let options = parseArguments(["--direct", "eventsToday"], environment: [:])

        let result = dispatchClientCommand(
            rawArguments: ["--direct", "eventsToday"],
            options: options,
            directRunner: directRunner,
            serverClient: transport
        )

        XCTAssertEqual(result, directResult)
        XCTAssertTrue(transport.sentArgv.isEmpty)
        XCTAssertEqual(directRunner.runCount, 1)
    }

    func testProtocolFailureDoesNotFallBack() {
        let directRunner = FakeRunner(result: CommandResult(stdout: "direct\n", stderr: "", exitCode: 0))
        let transport = FakeTransport(result: .failure(.protocolFailure("bad response")))
        let options = parseArguments(["eventsToday"], environment: [:])

        let result = dispatchClientCommand(
            rawArguments: ["eventsToday"],
            options: options,
            directRunner: directRunner,
            serverClient: transport
        )

        XCTAssertEqual(result.exitCode, 1)
        XCTAssertEqual(result.stderr, "Error: Server protocol failure: bad response\n")
        XCTAssertEqual(directRunner.runCount, 0)
    }
}

private final class FakeRunner: CommandRunning {
    private let result: CommandResult
    private(set) var runCount = 0

    init(result: CommandResult) {
        self.result = result
    }

    func run(options: ParsedOptions) -> CommandResult {
        runCount += 1
        return result
    }
}

private final class FakeTransport: CalBuddyClientTransport {
    private let result: Result<CommandResult, CalBuddyClientError>
    private(set) var sentArgv: [[String]] = []

    init(result: Result<CommandResult, CalBuddyClientError>) {
        self.result = result
    }

    func send(argv: [String], socketPath: String) -> Result<CommandResult, CalBuddyClientError> {
        sentArgv.append(argv)
        return result
    }
}
