import Foundation
import KiwiDeskCore

/// The live changes this MCP session made and has not kept
/// (#1685 ▸ Ruling 4): the leaf ids Core's change reports named,
/// never a diff of its own, and nothing Core did not report.
/// One per server, read and written on its one request loop.
final class MCPKeepLedger {
    /// Every leaf reported since the last epoch, by id.
    private var leaves: [String: TouchedLeaf] = [:]
    private var epoch: Int?
    private var profile: String?
    /// Pending ids a load or reload replaced, told once.
    private var replaced: [String] = []

    /// Takes in one answer's report. An epoch that moved means
    /// the live settings were replaced, so what was pending is gone.
    func absorb(_ report: ChangeReport) {
        if let epoch, epoch != report.epoch {
            replaced += pending.map(\.id)
            leaves = [:]
        }
        epoch = report.epoch
        profile = report.profile
        for leaf in report.touched { leaves[leaf.id] = leaf }
    }

    /// Ends the leaves a keep wrote, and takes the verdict it gave
    /// for any it could not.
    func settle(kept: [String], refused: [TouchedLeaf]) {
        for id in kept { leaves[id] = nil }
        for leaf in refused { leaves[leaf.id] = leaf }
    }

    /// The leaves a keep can still write, in id order.
    var pending: [TouchedLeaf] {
        leaves.values.filter { $0.notKeepable == nil }
            .sorted { $0.id < $1.id }
    }

    /// The leaves no keep can write, in id order.
    var refused: [TouchedLeaf] {
        leaves.values.filter { $0.notKeepable != nil }
            .sorted { $0.id < $1.id }
    }

    /// What every result reports while anything is outstanding: the
    /// live, unkept leaves with their owner, the pending count, the
    /// unkeepable ones and — once — what a load replaced. Nil where
    /// there is nothing to say.
    func status() -> (text: String, structure: JSONValue)? {
        let pending = pending
        let refused = refused
        let replaced = replaced
        self.replaced = []
        guard !pending.isEmpty || !refused.isEmpty || !replaced.isEmpty
        else { return nil }
        var lines: [String] = []
        if !pending.isEmpty {
            lines.append(MCPWording.unkept(pending, profile: profile))
        }
        lines += refused.map(MCPWording.unkeepable)
        if !replaced.isEmpty {
            lines.append(MCPWording.replaced(replaced.count))
        }
        var fields: [String: JSONValue] = [
            "pending": .number(Double(pending.count)),
            "live_not_kept": .array(pending.map(Self.json)),
            "not_keepable": .array(refused.map(Self.json)),
        ]
        if let profile { fields["profile"] = .string(profile) }
        if !replaced.isEmpty {
            fields["replaced"] = .array(replaced.map(JSONValue.string))
        }
        return (lines.joined(separator: "\n"), .object(fields))
    }

    static func json(_ leaf: TouchedLeaf) -> JSONValue {
        var fields: [String: JSONValue] = [
            "id": .string(leaf.id),
            "owner": .string(leaf.owner.rawValue),
        ]
        if let refusal = leaf.notKeepable {
            fields["not_keepable"] = .string(refusal.rawValue)
        }
        return .object(fields)
    }
}
