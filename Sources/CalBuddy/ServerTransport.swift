import Darwin
import Foundation

enum CalBuddyClientError: Error, Equatable, CustomStringConvertible {
    case unavailable(String)
    case protocolFailure(String)

    var description: String {
        switch self {
        case .unavailable(let message):
            return message
        case .protocolFailure(let message):
            return message
        }
    }
}

protocol CalBuddyClientTransport {
    func send(argv: [String], socketPath: String) -> Result<CommandResult, CalBuddyClientError>
}

final class CalBuddySocketClient: CalBuddyClientTransport {
    func send(argv: [String], socketPath: String) -> Result<CommandResult, CalBuddyClientError> {
        guard FileManager.default.fileExists(atPath: socketPath) else {
            return .failure(.unavailable("server socket does not exist at \(socketPath)"))
        }

        let requestID = UUID().uuidString
        let request = CalBuddyServerRequest(
            protocolVersion: calBuddyProtocolVersion,
            clientVersion: version,
            requestID: requestID,
            argv: argv
        )

        let frame: Data
        do {
            frame = try encodeProtocolFrame(request)
        } catch {
            return .failure(.protocolFailure("failed to encode server request: \(error)"))
        }

        do {
            let fd = try connectUnixSocket(path: socketPath)
            defer { close(fd) }

            try writeAll(frame, to: fd)
            let header = try readExactly(4, from: fd)
            let payloadLength = header.reduce(UInt32(0)) { partial, byte in
                (partial << 8) | UInt32(byte)
            }
            let payload = try readExactly(Int(payloadLength), from: fd)
            var responseFrame = Data()
            responseFrame.append(header)
            responseFrame.append(payload)

            let response = try decodeProtocolFrame(responseFrame, as: CalBuddyServerResponse.self)
            try validateServerResponse(response, requestID: requestID)
            return .success(CommandResult(
                stdout: response.stdout,
                stderr: response.stderr,
                exitCode: response.exitCode
            ))
        } catch let error as SocketTransportError {
            switch error.kind {
            case .unavailable:
                return .failure(.unavailable(error.description))
            case .protocolFailure:
                return .failure(.protocolFailure(error.description))
            }
        } catch {
            return .failure(.protocolFailure("\(error)"))
        }
    }
}

final class CalBuddyServer {
    private let socketPath: String
    private let runner: CommandRunning
    private let workQueue = DispatchQueue(label: "calbuddy.server-calendar")

    init(socketPath: String, runner: CommandRunning) {
        self.socketPath = socketPath
        self.runner = runner
    }

    func runForever() -> CommandResult {
        unlink(socketPath)

        do {
            let fd = try bindUnixSocket(path: socketPath)
            defer {
                close(fd)
                unlink(socketPath)
            }

            installSignalHandlers(socketPath: socketPath)
            fputs("calbuddy server listening on \(socketPath)\n", stderr)

            while true {
                let client = accept(fd, nil, nil)
                if client < 0 {
                    if errno == EINTR {
                        continue
                    }
                    return CommandResult(
                        stdout: "",
                        stderr: "Error: Failed to accept client connection: \(posixErrorDescription())\n",
                        exitCode: 1
                    )
                }
                handle(client)
            }
        } catch {
            unlink(socketPath)
            return CommandResult(stdout: "", stderr: "Error: Failed to start server: \(error)\n", exitCode: 1)
        }
    }

    private func handle(_ fd: Int32) {
        defer { close(fd) }

        let response = workQueue.sync {
            makeResponse(from: readRequest(from: fd))
        }

        do {
            try writeAll(try encodeProtocolFrame(response), to: fd)
        } catch {
            // The client may have disconnected; the foreground server keeps running.
        }
    }

    private func readRequest(from fd: Int32) -> Result<CalBuddyServerRequest, Error> {
        do {
            let header = try readExactly(4, from: fd)
            let payloadLength = header.reduce(UInt32(0)) { partial, byte in
                (partial << 8) | UInt32(byte)
            }
            let payload = try readExactly(Int(payloadLength), from: fd)
            var frame = Data()
            frame.append(header)
            frame.append(payload)
            return .success(try decodeProtocolFrame(frame, as: CalBuddyServerRequest.self))
        } catch {
            return .failure(error)
        }
    }

    private func makeResponse(from requestResult: Result<CalBuddyServerRequest, Error>) -> CalBuddyServerResponse {
        switch requestResult {
        case .failure(let error):
            let result = CommandResult(
                stdout: "",
                stderr: "Error: Server request failed: \(error)\n",
                exitCode: 1
            )
            return CalBuddyServerResponse(
                requestID: "",
                result: result,
                error: CalBuddyServerError(code: "request_failed", message: "\(error)")
            )

        case .success(let request):
            guard request.protocolVersion == calBuddyProtocolVersion else {
                let message = "protocol mismatch: expected \(calBuddyProtocolVersion), got \(request.protocolVersion)"
                return CalBuddyServerResponse(
                    requestID: request.requestID,
                    result: CommandResult(stdout: "", stderr: "Error: Server \(message)\n", exitCode: 1),
                    error: CalBuddyServerError(code: "protocol_mismatch", message: message)
                )
            }
            let options = parseArguments(request.argv, environment: [:])
            return CalBuddyServerResponse(requestID: request.requestID, result: runner.run(options: options))
        }
    }
}

private enum SocketErrorKind {
    case unavailable
    case protocolFailure
}

private struct SocketTransportError: Error, CustomStringConvertible {
    let kind: SocketErrorKind
    let message: String

    var description: String { message }
}

private func connectUnixSocket(path: String) throws -> Int32 {
    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else {
        throw SocketTransportError(kind: .unavailable, message: "socket failed: \(posixErrorDescription())")
    }

    do {
        try withUnixSocketAddress(path: path) { address, length in
            guard connect(fd, address, length) == 0 else {
                throw SocketTransportError(kind: .unavailable, message: "connect failed: \(posixErrorDescription())")
            }
        }
        return fd
    } catch {
        close(fd)
        throw error
    }
}

private func bindUnixSocket(path: String) throws -> Int32 {
    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else {
        throw SocketTransportError(kind: .unavailable, message: "socket failed: \(posixErrorDescription())")
    }

    do {
        try withUnixSocketAddress(path: path) { address, length in
            guard bind(fd, address, length) == 0 else {
                throw SocketTransportError(kind: .unavailable, message: "bind failed: \(posixErrorDescription())")
            }
        }
        guard listen(fd, SOMAXCONN) == 0 else {
            throw SocketTransportError(kind: .unavailable, message: "listen failed: \(posixErrorDescription())")
        }
        return fd
    } catch {
        close(fd)
        throw error
    }
}

private func withUnixSocketAddress<T>(
    path: String,
    _ body: (UnsafePointer<sockaddr>, socklen_t) throws -> T
) throws -> T {
    let pathBytes = Array(path.utf8)
    var address = sockaddr_un()
    let maxPathLength = MemoryLayout.size(ofValue: address.sun_path)

    guard pathBytes.count < maxPathLength else {
        throw SocketTransportError(kind: .unavailable, message: "socket path is too long: \(path)")
    }

    address.sun_family = sa_family_t(AF_UNIX)
    withUnsafeMutableBytes(of: &address.sun_path) { rawBuffer in
        rawBuffer.initializeMemory(as: CChar.self, repeating: 0)
        path.withCString { source in
            rawBuffer.copyMemory(from: UnsafeRawBufferPointer(start: source, count: pathBytes.count + 1))
        }
    }

    let length = socklen_t(MemoryLayout<sa_family_t>.size + pathBytes.count + 1)
    return try withUnsafePointer(to: &address) { pointer in
        try pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
            try body(sockaddrPointer, length)
        }
    }
}

private func writeAll(_ data: Data, to fd: Int32) throws {
    try data.withUnsafeBytes { rawBuffer in
        guard let baseAddress = rawBuffer.baseAddress else { return }
        var offset = 0
        while offset < rawBuffer.count {
            let written = Darwin.write(fd, baseAddress.advanced(by: offset), rawBuffer.count - offset)
            if written < 0 {
                if errno == EINTR {
                    continue
                }
                throw SocketTransportError(kind: .protocolFailure, message: "write failed: \(posixErrorDescription())")
            }
            if written == 0 {
                throw SocketTransportError(kind: .protocolFailure, message: "write returned 0 bytes")
            }
            offset += written
        }
    }
}

private func readExactly(_ byteCount: Int, from fd: Int32) throws -> Data {
    guard byteCount >= 0 else {
        throw CalBuddyProtocolError.invalidLength
    }

    var data = Data(count: byteCount)
    try data.withUnsafeMutableBytes { rawBuffer in
        guard let baseAddress = rawBuffer.baseAddress else { return }
        var offset = 0
        while offset < byteCount {
            let bytesRead = Darwin.read(fd, baseAddress.advanced(by: offset), byteCount - offset)
            if bytesRead < 0 {
                if errno == EINTR {
                    continue
                }
                throw SocketTransportError(kind: .protocolFailure, message: "read failed: \(posixErrorDescription())")
            }
            if bytesRead == 0 {
                throw CalBuddyProtocolError.incompleteFrame(expected: byteCount, actual: offset)
            }
            offset += bytesRead
        }
    }
    return data
}

private func posixErrorDescription() -> String {
    String(cString: strerror(errno))
}

nonisolated(unsafe) private var activeServerSocketPath: String?

private func installSignalHandlers(socketPath: String) {
    activeServerSocketPath = socketPath
    signal(SIGINT) { _ in
        if let path = activeServerSocketPath {
            unlink(path)
        }
        exit(130)
    }
    signal(SIGTERM) { _ in
        if let path = activeServerSocketPath {
            unlink(path)
        }
        exit(143)
    }
}
