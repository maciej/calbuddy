import Foundation

private struct ActionLogListResponse: Encodable {
    let schemaVersion: String
    let command: String
    let count: Int
    let entries: [ActionLogEntry]
}

private struct ActionLogShowResponse: Encodable {
    let schemaVersion: String
    let command: String
    let entry: ActionLogEntry
}

func formatActionLogList(_ entries: [ActionLogEntry], jsonMode: JSONMode?) throws -> String {
    if jsonMode != nil {
        return try encodeActionLogJSON(ActionLogListResponse(
            schemaVersion: "1.0",
            command: "actionLog",
            count: entries.count,
            entries: entries
        ))
    }

    return entries.map { entry in
        let target = entry.targetIdentifiers.first ?? "-"
        let forced = entry.forced ? " forced" : ""
        let reverted = entry.revertedActionID.map { " reverts:\($0)" } ?? ""
        return "\(entry.actionID) \(ActionLogStore.iso8601String(entry.timestamp)) \(entry.actionType.rawValue) \(target)\(forced)\(reverted)"
    }.joined(separator: "\n")
}

func formatActionLogEntry(_ entry: ActionLogEntry, jsonMode: JSONMode?) throws -> String {
    if jsonMode != nil {
        return try encodeActionLogJSON(ActionLogShowResponse(
            schemaVersion: "1.0",
            command: "actionLog",
            entry: entry
        ))
    }

    var lines = [
        "Action ID: \(entry.actionID)",
        "Timestamp: \(ActionLogStore.iso8601String(entry.timestamp))",
        "Type: \(entry.actionType.rawValue)",
        "Status: \(entry.status.rawValue)",
        "Targets: \(entry.targetIdentifiers.joined(separator: ", "))",
    ]
    if let actor = entry.actor {
        lines.append("Actor: \(actor)")
    }
    if let source = entry.source {
        lines.append("Source: \(source)")
    }
    if entry.forced {
        lines.append("Forced: true")
    }
    if let revertedActionID = entry.revertedActionID {
        lines.append("Reverted Action ID: \(revertedActionID)")
    }
    lines.append("Command: \(entry.commandLine.joined(separator: " "))")
    lines.append("Inverse: \(entry.inverseOperation.kind.rawValue)")
    if let before = entry.beforeSnapshot {
        lines.append("Before: \(before.title) @ \(ActionLogStore.iso8601String(before.startDate))")
    } else {
        lines.append("Before: null")
    }
    if let after = entry.afterSnapshot {
        lines.append("After: \(after.title) @ \(ActionLogStore.iso8601String(after.startDate))")
    } else {
        lines.append("After: null")
    }
    return lines.joined(separator: "\n")
}

private func encodeActionLogJSON<T: Encodable>(_ value: T) throws -> String {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .custom { date, encoder in
        var container = encoder.singleValueContainer()
        try container.encode(ActionLogStore.iso8601String(date))
    }
    encoder.keyEncodingStrategy = .convertToSnakeCase
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes, .prettyPrinted]
    let data = try encoder.encode(value)
    return String(decoding: data, as: UTF8.self)
}
