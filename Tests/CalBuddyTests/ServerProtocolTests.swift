import Foundation
import XCTest
@testable import CalBuddy

final class ServerProtocolTests: XCTestCase {
    func testRequestFrameRoundTrip() throws {
        let request = CalBuddyServerRequest(
            protocolVersion: calBuddyProtocolVersion,
            clientVersion: "1.0.0",
            requestID: "abc",
            argv: ["eventsToday"]
        )

        let frame = try encodeProtocolFrame(request)
        let decoded = try decodeProtocolFrame(frame, as: CalBuddyServerRequest.self)

        XCTAssertEqual(decoded, request)
    }

    func testResponseFrameRoundTrip() throws {
        let response = CalBuddyServerResponse(
            requestID: "abc",
            result: CommandResult(stdout: "OK\n", stderr: "", exitCode: 0)
        )

        let frame = try encodeProtocolFrame(response)
        let decoded = try decodeProtocolFrame(frame, as: CalBuddyServerResponse.self)

        XCTAssertEqual(decoded, response)
    }

    func testMalformedFrameTooShort() {
        XCTAssertThrowsError(try decodeProtocolFrame(Data([0x00, 0x00]), as: CalBuddyServerRequest.self)) { error in
            XCTAssertEqual(error as? CalBuddyProtocolError, .frameTooShort)
        }
    }

    func testMalformedFrameIncompletePayload() {
        let frame = Data([0x00, 0x00, 0x00, 0x05, 0x7B])

        XCTAssertThrowsError(try decodeProtocolFrame(frame, as: CalBuddyServerRequest.self)) { error in
            XCTAssertEqual(error as? CalBuddyProtocolError, .incompleteFrame(expected: 9, actual: 5))
        }
    }

    func testProtocolMismatchValidation() {
        let response = CalBuddyServerResponse(
            protocolVersion: 99,
            serverVersion: "1.0.0",
            requestID: "abc",
            result: CommandResult(stdout: "", stderr: "", exitCode: 0)
        )

        XCTAssertThrowsError(try validateServerResponse(response, requestID: "abc")) { error in
            XCTAssertEqual(
                error as? CalBuddyProtocolError,
                .protocolMismatch(expected: calBuddyProtocolVersion, actual: 99)
            )
        }
    }

    func testRequestIDMismatchValidation() {
        let response = CalBuddyServerResponse(
            requestID: "server-id",
            result: CommandResult(stdout: "", stderr: "", exitCode: 0)
        )

        XCTAssertThrowsError(try validateServerResponse(response, requestID: "client-id")) { error in
            XCTAssertEqual(
                error as? CalBuddyProtocolError,
                .requestIDMismatch(expected: "client-id", actual: "server-id")
            )
        }
    }

    func testServerRequestLogLineIncludesRequestMetadataAndQuotedArguments() {
        let request = CalBuddyServerRequest(
            protocolVersion: calBuddyProtocolVersion,
            clientVersion: "1.0.0",
            requestID: "abc",
            argv: ["eventsFrom:2026-05-21", "to:2026-05-22", "--includeCals", "Work Calendar", "Bob's"]
        )
        let receivedAt = Date(timeIntervalSince1970: 1_777_859_790)

        let line = formatServerRequestLogLine(request, receivedAt: receivedAt)

        XCTAssertTrue(line.hasPrefix("[2026-05-04T01:56:30Z] calbuddy server request"))
        XCTAssertTrue(line.contains("id=abc"))
        XCTAssertTrue(line.contains("client=1.0.0"))
        XCTAssertTrue(line.contains("argv=eventsFrom:2026-05-21 to:2026-05-22 --includeCals 'Work Calendar' 'Bob'\\''s'"))
    }
}
