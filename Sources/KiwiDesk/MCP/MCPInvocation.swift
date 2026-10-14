import Foundation

/// How an AI app starts `kiwidesk mcp` (#1685): the CLI verb and
/// the `mcpServers` entry every setup path hands out — the AI
/// page's setup prompt today, the #2258 extension later.
enum MCPInvocation {
    /// The CLI verb `runCLI` dispatches to `MCPServer`.
    static let verb = "mcp"
    /// The server's name inside an `mcpServers` map.
    static let serverName = "kiwidesk"

    /// The `mcpServers` entry for `executable` as one line of
    /// JSON, encoded rather than interpolated so any path stays
    /// valid, slashes kept readable.
    static func serverEntry(executable: String) -> String {
        let entry = [
            "mcpServers": [
                serverName: Server(command: executable, args: [verb])
            ]
        ]
        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .sortedKeys, .withoutEscapingSlashes,
        ]
        guard let data = try? encoder.encode(entry),
            let json = String(data: data, encoding: .utf8)
        else { return "" }
        return json
    }

    private struct Server: Encodable {
        let command: String
        let args: [String]
    }
}
