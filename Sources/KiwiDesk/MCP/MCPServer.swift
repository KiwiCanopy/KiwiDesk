import Foundation
import KiwiDeskCore

/// `kiwidesk mcp`: a tools-only MCP server on stdin/stdout
/// (#1685), hand-rolled by ruling rather than an SDK linked into
/// the signed app. It holds no KiwiDesk state: every tool call is
/// answered from the binary's own API reference or forwarded to
/// the running app over its socket.
final class MCPServer {
    private let tools: MCPTools

    init(tools: MCPTools = MCPTools()) {
        self.tools = tools
    }

    /// Reads requests until stdin closes. stdout carries only
    /// JSON-RPC lines; nothing else may be printed there.
    static func run() -> Int32 {
        // A client or app that hangs up mid-write ends the loop
        // with an error, never a signal.
        signal(SIGPIPE, SIG_IGN)
        let server = MCPServer()
        while let line = readLine(strippingNewline: true) {
            guard
                !line.allSatisfy(\.isWhitespace),
                let reply = server.reply(to: line),
                let text = MCPReply.line(reply)
            else { continue }
            do {
                try FileHandle.standardOutput.write(
                    contentsOf: Data((text + "\n").utf8)
                )
            } catch {
                return 0
            }
        }
        return 0
    }

    /// The reply to one line, or nil for a notification.
    func reply(to line: String) -> JSONValue? {
        let request: MCPRequest
        switch MCPRequest.parse(line) {
        case .failure(let failed):
            return MCPReply.error(failed.id, failed.failure)
        case .success(let parsed):
            request = parsed
        }
        guard let id = request.id else { return nil }
        do {
            return MCPReply.result(id, try answer(request))
        } catch let failure as MCPFailure {
            return MCPReply.error(id, failure)
        } catch {
            return MCPReply.error(
                id,
                MCPFailure(.internalError, "\(error)")
            )
        }
    }

    private func answer(_ request: MCPRequest) throws -> JSONValue {
        let version = request.metaVersion
        // Discovery answers any version: it is how a client
        // learns which ones are served.
        if let version, request.method != "server/discover",
            !MCPProtocol.modern.contains(version)
        {
            throw MCPProtocol.unsupported(version)
        }
        let modern = version != nil
        switch request.method {
        case "initialize":
            let asked = request.params["protocolVersion"]?.stringValue
            return MCPProtocol.initializeResult(
                version: MCPProtocol.negotiated(asked)
            )
        case "server/discover":
            return MCPProtocol.discoverResult
        case "ping":
            return .object([:])
        case "tools/list":
            var result = ["tools": tools.definitions]
            if modern {
                result["ttlMs"] = .number(
                    MCPProtocol.listTTLMilliseconds
                )
                result["cacheScope"] = .string("private")
            }
            return complete(.object(result), modern: modern)
        case "tools/call":
            return complete(try tools.call(request.params), modern: modern)
        default:
            throw MCPFailure(
                .methodNotFound,
                "method not found: \(request.method)"
            )
        }
    }

    /// A modern result carries `resultType`; a legacy one stays
    /// in the shape its revision defines.
    private func complete(_ result: JSONValue, modern: Bool) -> JSONValue {
        guard modern, case .object(var fields) = result else {
            return result
        }
        fields["resultType"] = .string("complete")
        return .object(fields)
    }
}
