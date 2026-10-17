import Foundation
import KiwiDeskCore

/// One JSON-RPC 2.0 message from an MCP client (#1685). A message
/// without an `id` is a notification and gets no reply.
struct MCPRequest {
    let id: JSONValue?
    let method: String
    let params: [String: JSONValue]

    /// The protocol version a modern request names in `_meta`;
    /// nil for a legacy request, which names none.
    var metaVersion: String? {
        guard case .object(let meta)? = params["_meta"] else {
            return nil
        }
        return meta[MCPProtocol.versionKey]?.stringValue
    }

    /// Parses one line, or answers why it is not a request, with
    /// the request's id where one could be read.
    static func parse(
        _ line: String
    ) -> Result<MCPRequest, MCPParseFailure> {
        guard let data = line.data(using: .utf8),
            let value = try? JSONDecoder().decode(
                JSONValue.self,
                from: data
            )
        else {
            return .failure(
                MCPParseFailure(MCPFailure(.parseError, "parse error"))
            )
        }
        guard case .object(let fields) = value else {
            return .failure(MCPParseFailure(invalid))
        }
        let id = fields["id"]
        if let id, !isValidID(id) {
            return .failure(MCPParseFailure(invalid))
        }
        guard let method = fields["method"]?.stringValue else {
            return .failure(MCPParseFailure(invalid, id: id))
        }
        var params: [String: JSONValue] = [:]
        if case .object(let given)? = fields["params"] {
            params = given
        }
        return .success(MCPRequest(id: id, method: method, params: params))
    }

    private static let invalid = MCPFailure(
        .invalidRequest,
        "invalid request"
    )

    /// MCP ids are strings or integers, and an integer must survive
    /// the `Double` `JSONValue` carries it in.
    static func isValidID(_ id: JSONValue) -> Bool {
        switch id {
        case .string:
            return true
        case .number(let n):
            return n == n.rounded() && abs(n) <= 9_007_199_254_740_991
        default:
            return false
        }
    }
}

/// A line that is no request, and the id to answer it under.
struct MCPParseFailure: Error {
    let failure: MCPFailure
    var id: JSONValue?

    init(_ failure: MCPFailure, id: JSONValue? = nil) {
        self.failure = failure
        self.id = id
    }
}

/// A JSON-RPC error reply. Messages stay English: a protocol
/// contract, like the CLI's (core-boundaries.md).
struct MCPFailure: Error {
    enum Code: Int {
        case parseError = -32700
        case invalidRequest = -32600
        case methodNotFound = -32601
        case invalidParams = -32602
        case internalError = -32603
        case unsupportedProtocolVersion = -32022
    }

    let code: Code
    let message: String
    var data: JSONValue?

    init(_ code: Code, _ message: String, data: JSONValue? = nil) {
        self.code = code
        self.message = message
        self.data = data
    }
}

/// Builds and writes JSON-RPC replies, one compact line each.
enum MCPReply {
    static func result(_ id: JSONValue?, _ result: JSONValue) -> JSONValue {
        .object([
            "jsonrpc": .string("2.0"),
            "id": id ?? .null,
            "result": result,
        ])
    }

    static func error(_ id: JSONValue?, _ failure: MCPFailure) -> JSONValue {
        var error: [String: JSONValue] = [
            "code": .number(Double(failure.code.rawValue)),
            "message": .string(failure.message),
        ]
        if let data = failure.data { error["data"] = data }
        return .object([
            "jsonrpc": .string("2.0"),
            "id": id ?? .null,
            "error": .object(error),
        ])
    }

    /// One line of JSON with no newline inside it: stdout carries
    /// nothing but these (the stdio transport's framing).
    static func line(_ message: JSONValue) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .sortedKeys, .withoutEscapingSlashes,
        ]
        guard let data = try? encoder.encode(message) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}
