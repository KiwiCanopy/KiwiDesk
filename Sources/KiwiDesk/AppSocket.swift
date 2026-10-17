import Foundation
import KiwiDeskCore

/// The one way this binary's command-line halves reach the running
/// app: the CLI and `kiwidesk mcp` (#1685) both connect here.
enum AppSocket {
    /// Connects to the app's socket. A timeout bounds every send
    /// and read after the connect; nil waits as long as the app
    /// takes.
    static func connect(timeout seconds: Int? = nil) throws -> SocketClient {
        let client = try SocketClient(path: KiwiCore.defaultSocketPath)
        if let seconds { client.setTimeout(seconds: seconds) }
        return client
    }
}
