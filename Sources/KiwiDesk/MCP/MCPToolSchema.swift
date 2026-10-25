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

    /// A string property limited to `values`.
    static func choice(
        _ description: String,
        _ values: [String]
    ) -> JSONValue {
        .object([
            "type": .string("string"),
            "description": .string(description),
            "enum": .array(values.map(JSONValue.string)),
        ])
    }

    /// One record argument as a property: its JSON type from the
    /// argument's kind, a choice's values as its enum.
    static func property(
        for argument: APIArgument,
        _ description: String
    ) -> JSONValue {
        var fields: [String: JSONValue] = [
            "description": .string(description)
        ]
        switch argument.kind {
        case .number: fields["type"] = .string("number")
        case .integer, .desktop: fields["type"] = .string("integer")
        case .boolean: fields["type"] = .string("boolean")
        case .text, .color: fields["type"] = .string("string")
        case .space:
            // A Space id is a string or a number (AGENTS.md §5).
            fields["type"] = .array([.string("string"), .string("integer")])
        case .choice(let choice):
            fields["type"] = .string("string")
            fields["enum"] = .array(choice.values.map(JSONValue.string))
        case .window:
            // A window id as `get_state` reports it.
            fields["type"] = .string("integer")
        case .callback, .table:
            break
        }
        return .object(fields)
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
