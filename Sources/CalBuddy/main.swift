import Foundation

let rawArguments = Array(CommandLine.arguments.dropFirst())
let options = parseArguments(rawArguments)

if case .serve = options.command {
    let fetcher = EventFetcher()
    guard fetcher.requestCalendarAccess() else {
        let result = CommandResult(
            stdout: "",
            stderr: "Error: Calendar access denied. Grant access in System Settings > Privacy & Security > Calendars.\n",
            exitCode: 1
        )
        write(result)
        exit(Int32(result.exitCode))
    }
    let server = CalBuddyServer(
        socketPath: options.socketPath,
        runner: DirectCommandRunner(fetcher: fetcher, hasCalendarAccess: true)
    )
    let result = server.runForever()
    write(result)
    exit(Int32(result.exitCode))
}

let result = dispatchClientCommand(
    rawArguments: rawArguments,
    options: options,
    directRunner: DirectCommandRunner(),
    serverClient: CalBuddySocketClient()
)
write(result)
exit(Int32(result.exitCode))

private func write(_ result: CommandResult) {
    if !result.stdout.isEmpty {
        FileHandle.standardOutput.write(Data(result.stdout.utf8))
    }
    if !result.stderr.isEmpty {
        FileHandle.standardError.write(Data(result.stderr.utf8))
    }
}
