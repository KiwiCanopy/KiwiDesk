import Foundation

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
