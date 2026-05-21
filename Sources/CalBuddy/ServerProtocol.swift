import Foundation

let calBuddyProtocolVersion = 1

struct CalBuddyServerError: Codable, Equatable, Sendable {
    let code: String
    let message: String
}

struct CalBuddyServerRequest: Codable, Equatable, Sendable {
    let protocolVersion: Int
    let clientVersion: String
    let requestID: String
    let argv: [String]

    enum CodingKeys: String, CodingKey {
        case protocolVersion = "protocol_version"
        case clientVersion = "client_version"
        case requestID = "request_id"
        case argv
    }
}

struct CalBuddyServerResponse: Codable, Equatable, Sendable {
    let protocolVersion: Int
    let serverVersion: String
    let requestID: String
    let exitCode: Int
    let stdout: String
    let stderr: String
    let error: CalBuddyServerError?

    enum CodingKeys: String, CodingKey {
        case protocolVersion = "protocol_version"
        case serverVersion = "server_version"
        case requestID = "request_id"
        case exitCode = "exit_code"
        case stdout
        case stderr
        case error
    }

    init(
        protocolVersion: Int = calBuddyProtocolVersion,
        serverVersion: String = version,
        requestID: String,
        result: CommandResult,
        error: CalBuddyServerError? = nil
    ) {
        self.protocolVersion = protocolVersion
        self.serverVersion = serverVersion
        self.requestID = requestID
        self.exitCode = result.exitCode
        self.stdout = result.stdout
        self.stderr = result.stderr
        self.error = error
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        protocolVersion = try container.decode(Int.self, forKey: .protocolVersion)
        serverVersion = try container.decode(String.self, forKey: .serverVersion)
        requestID = try container.decode(String.self, forKey: .requestID)
        exitCode = try container.decode(Int.self, forKey: .exitCode)
        stdout = try container.decode(String.self, forKey: .stdout)
        stderr = try container.decode(String.self, forKey: .stderr)
        error = try container.decodeIfPresent(CalBuddyServerError.self, forKey: .error)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(protocolVersion, forKey: .protocolVersion)
        try container.encode(serverVersion, forKey: .serverVersion)
        try container.encode(requestID, forKey: .requestID)
        try container.encode(exitCode, forKey: .exitCode)
        try container.encode(stdout, forKey: .stdout)
        try container.encode(stderr, forKey: .stderr)
        try container.encodeIfPresent(error, forKey: .error)
    }
}

enum CalBuddyProtocolError: Error, CustomStringConvertible, Equatable {
    case frameTooShort
    case invalidLength
    case incompleteFrame(expected: Int, actual: Int)
    case payloadTooLarge(Int)
    case invalidJSON(String)
    case protocolMismatch(expected: Int, actual: Int)
    case requestIDMismatch(expected: String, actual: String)

    var description: String {
        switch self {
        case .frameTooShort:
            return "frame is shorter than the 4-byte length prefix"
        case .invalidLength:
            return "frame length prefix is invalid"
        case .incompleteFrame(let expected, let actual):
            return "incomplete frame: expected \(expected) bytes, got \(actual)"
        case .payloadTooLarge(let size):
            return "payload is too large: \(size) bytes"
        case .invalidJSON(let message):
            return "invalid JSON payload: \(message)"
        case .protocolMismatch(let expected, let actual):
            return "protocol mismatch: expected \(expected), got \(actual)"
        case .requestIDMismatch(let expected, let actual):
            return "request ID mismatch: expected \(expected), got \(actual)"
        }
    }
}

private let maxFramePayloadSize = 16 * 1024 * 1024

private func protocolJSONEncoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.withoutEscapingSlashes]
    return encoder
}

private func protocolJSONDecoder() -> JSONDecoder {
    JSONDecoder()
}

func encodeProtocolFrame<T: Encodable>(_ value: T) throws -> Data {
    let payload = try protocolJSONEncoder().encode(value)
    guard payload.count <= maxFramePayloadSize else {
        throw CalBuddyProtocolError.payloadTooLarge(payload.count)
    }

    var length = UInt32(payload.count).bigEndian
    var frame = Data(bytes: &length, count: MemoryLayout<UInt32>.size)
    frame.append(payload)
    return frame
}

func decodeProtocolFrame<T: Decodable>(_ frame: Data, as type: T.Type) throws -> T {
    guard frame.count >= 4 else {
        throw CalBuddyProtocolError.frameTooShort
    }

    let length = frame.prefix(4).reduce(UInt32(0)) { partial, byte in
        (partial << 8) | UInt32(byte)
    }
    guard length <= maxFramePayloadSize else {
        throw CalBuddyProtocolError.payloadTooLarge(Int(length))
    }

    let expectedCount = Int(length) + 4
    guard frame.count == expectedCount else {
        throw CalBuddyProtocolError.incompleteFrame(expected: expectedCount, actual: frame.count)
    }

    do {
        return try protocolJSONDecoder().decode(type, from: Data(frame.dropFirst(4)))
    } catch {
        throw CalBuddyProtocolError.invalidJSON(error.localizedDescription)
    }
}

func validateServerResponse(_ response: CalBuddyServerResponse, requestID: String) throws {
    guard response.protocolVersion == calBuddyProtocolVersion else {
        throw CalBuddyProtocolError.protocolMismatch(
            expected: calBuddyProtocolVersion,
            actual: response.protocolVersion
        )
    }
    guard response.requestID == requestID else {
        throw CalBuddyProtocolError.requestIDMismatch(
            expected: requestID,
            actual: response.requestID
        )
    }
}
