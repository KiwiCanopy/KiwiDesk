import Foundation
import KiwiDeskCore

/// The JSON a tool definition is built from (#1685).
enum MCPToolSchema {
    static func string(_ description: String) -> JSONValue {
        .object([
            "type": .string("string"),
            "description": .string(description),
        ])
    }

    /// `command` and `args`, as `run` and `run_batch` take them.
    static let command: [String: JSONValue] = [
        "command": string("The command name, as list_commands shows it."),
        "args": .object([
            "type": .string("array"),
            "description": .string(
                "Positional arguments in the order help lists them."
            ),
            "items": .object([:]),
        ]),
    ]

    static func tool(
        _ name: String,
        title: String,
        _ description: String,
        properties: [String: JSONValue] = [:],
        required: [String] = [],
        readOnly: Bool = false,
        destructive: Bool = false
    ) -> JSONValue {
        var schema: [String: JSONValue] = [
            "type": .string("object"),
            "properties": .object(properties),
            "additionalProperties": .bool(false),
        ]
        if !required.isEmpty {
            schema["required"] = .array(required.map(JSONValue.string))
        }
        return .object([
            "name": .string(name),
            "title": .string(title),
            "description": .string(description),
            "inputSchema": .object(schema),
            "annotations": .object([
                "title": .string(title),
                "readOnlyHint": .bool(readOnly),
                "destructiveHint": .bool(destructive),
                "idempotentHint": .bool(readOnly),
                "openWorldHint": .bool(false),
            ]),
        ])
    }
}
