import Foundation
import KiwiDeskCore

/// The `keep` tool and the keep status every result carries
/// (#1685 ▸ Ruling 4): a setter's change is live and not kept
/// until the user asks, and `keep` writes exactly the leaves this
/// session's change reports named, through Core's `keep_settings`.
extension MCPTools {
    static let keep = "keep"

    static let keepTool = Tool(
        name: keep,
        definition: MCPToolSchema.tool(
            keep,
            title: "Keep setting changes",
            "Makes this session's live setting changes permanent, "
                + "writing them into the live profile, or into the "
                + "shared look the profiles wearing it share. Call it "
                + "when the user asks to keep them — at once if they "
                + "asked for a change to last (\"from now on\"). "
                + "Without ids it keeps every pending change.",
            properties: [
                "ids": .object([
                    "type": .string("array"),
                    "items": .object(["type": .string("string")]),
                    "description": .string(
                        "Leaf ids from keep_status.live_not_kept"
                    ),
                ])
            ],
            required: []
        ),
        handle: { tools, arguments in
            tools.keep(arguments["ids"])
        }
    )

    func keep(_ value: JSONValue?) -> JSONValue {
        let pending = Set(ledger.pending.map(\.id))
        var ids = pending.sorted()
        switch value {
        case nil, .null?:
            break
        case .array(let given)?:
            let named = given.compactMap(\.stringValue)
            guard named.count == given.count else {
                return Self.failure("ids must be strings")
            }
            if let stray = named.first(where: { !pending.contains($0) }) {
                return Self.failure(
                    MCPWording.notPending(stray)
                )
            }
            ids = Set(named).sorted()
        default:
            return Self.failure("ids must be an array")
        }
        guard !ids.isEmpty else {
            return decorated(
                Self.result(MCPWording.nothingToKeep, structured: .object([:]))
            )
        }
        // Core refuses a keep whose epoch a load has moved past.
        let epoch = ledger.epoch ?? ""
        let outcome = outcome(
            of: CommandRequest(
                command: Self.keepCommand,
                args: ([epoch] + ids).map(JSONValue.string)
            )
        )
        guard outcome.ok, let data = outcome.data else {
            let stale = outcome.error == KiwiCore.staleKeepRefusal
            return decorated(
                Self.failure(stale ? MCPWording.staleKeep : outcome.text)
            )
        }
        let kept = Self.leaves(data, "kept")
        ledger.settle(
            kept: kept.map(\.id),
            refused: Self.leaves(data, "not_keepable")
        )
        let text = MCPWording.kept(
            kept,
            profile: data["profile"]?.stringValue,
            followers: data["followers"]
        )
        return decorated(Self.result(text, structured: data))
    }

    /// The Core verb `keep` sends; `run` refuses it and
    /// `list_commands` leaves it out, so every keep passes through
    /// the ledger.
    static let keepCommand = KiwiCore.keepSettingsCommand

    /// `result` with the ledger's status appended, while there is
    /// one: a line the model reads and `keep_status` beside the
    /// answer's own structure.
    func decorated(_ result: JSONValue) -> JSONValue {
        guard let status = ledger.status(),
            case .object(var fields) = result
        else { return result }
        if case .array(var content)? = fields["content"] {
            content.append(
                .object([
                    "type": .string("text"),
                    "text": .string(status.text),
                ])
            )
            fields["content"] = .array(content)
        }
        var structured: [String: JSONValue] = [:]
        if case .object(let given)? = fields["structuredContent"] {
            structured = given
        }
        structured["keep_status"] = status.structure
        fields["structuredContent"] = .object(structured)
        return .object(fields)
    }

    private static func leaves(_ data: JSONValue, _ key: String)
        -> [TouchedLeaf]
    {
        guard case .array(let items)? = data[key] else { return [] }
        return items.compactMap { item in
            guard let id = item["id"]?.stringValue,
                let owner = item["owner"]?.stringValue
                    .flatMap(KeepOwner.init(rawValue:))
            else { return nil }
            return TouchedLeaf(
                id: id,
                owner: owner,
                notKeepable: item["not_keepable"]?.stringValue
                    .flatMap(NotKeepable.init(rawValue:))
            )
        }
    }
}

extension JSONValue {
    /// An object's member, or nil for any other value.
    fileprivate subscript(_ key: String) -> JSONValue? {
        if case .object(let members) = self { return members[key] }
        return nil
    }
}
