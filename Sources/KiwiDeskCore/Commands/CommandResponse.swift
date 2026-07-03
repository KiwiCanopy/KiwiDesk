import Foundation

/// One request over the IPC socket:
/// `{"command": "focus", "args": ["left"]}`.
public struct CommandRequest: Codable, Sendable, Equatable {
    public var command: String
    public var args: [JSONValue]?

    public init(command: String, args: [JSONValue]? = nil) {
        self.command = command
        self.args = args
    }
}

/// One pushed event for stream subscribers:
/// `{"event": "space_change", "data": {...}}`.
public struct EventMessage: Codable, Sendable, Equatable {
    public var event: String
    public var data: JSONValue

    public init(event: String, data: JSONValue) {
        self.event = event
        self.data = data
    }
}

/// Uniform result of every KiwiDesk command, shared by the
/// Lua API, the CLI, and the IPC socket.
public struct CommandResponse: Codable, Sendable, Equatable {
    public var status: String
    public var data: JSONValue?
    public var error: String?

    public var isSuccess: Bool { status == "success" }

    public static func ok(
        _ data: JSONValue? = nil
    ) -> CommandResponse {
        CommandResponse(status: "success", data: data)
    }

    public static func fail(
        _ message: String
    ) -> CommandResponse {
        CommandResponse(status: "error", error: message)
    }
}
