import Foundation

func dispatchClientCommand(
    rawArguments: [String],
    options: ParsedOptions,
    directRunner: CommandRunning,
    serverClient: CalBuddyClientTransport
) -> CommandResult {
    if shouldRunLocally(options.command) || options.direct {
        return directRunner.run(options: options)
    }

    switch serverClient.send(argv: rawArguments, socketPath: options.socketPath) {
    case .success(let result):
        return result
    case .failure(.unavailable):
        return directRunner.run(options: options)
    case .failure(.protocolFailure(let message)):
        return CommandResult(
            stdout: "",
            stderr: "Error: Server protocol failure: \(message)\n",
            exitCode: 1
        )
    }
}

private func shouldRunLocally(_ command: Command) -> Bool {
    switch command {
    case .help, .version, .completion, .serve:
        return true
    case .eventsToday, .eventsTodayPlus, .eventsNow, .eventsFromTo, .calendars, .addEvent, .editEvent:
        return false
    }
}
