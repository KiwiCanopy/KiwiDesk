import Foundation
import KiwiDeskCore

/// The live changes this MCP session made and has not kept
/// (#1685 ▸ Ruling 4): what Core's change reports said of the
/// leaves this session touched — never a diff or a verdict of its
/// own. Every request asks Core to judge them again (`watch`), and
/// a leaf Core calls stored is no longer pending. One per server,
/// read and written on its one request loop.
final class MCPKeepLedger {
    /// Core's latest verdict on every leaf still outstanding, by id.
    private var leaves: [String: TouchedLeaf] = [:]
    /// The epoch of the latest report; a keep sends it back.
    private(set) var epoch: String?
    private var profile: String?
    /// Pending ids a load or reload replaced, told once.
    private var replaced: [String] = []

    /// The ids a request asks Core to judge.
    var watch: [String] { leaves.keys.sorted() }

    /// Takes in one answer's report. A leaf Core now calls stored
    /// leaves the ledger — told as replaced where the epoch moved,
    /// since a load put the stored value back; told nothing
    /// otherwise, since a Save or a value set back kept it.
    func absorb(_ report: ChangeReport) {
        let moved = epoch != nil && epoch != report.epoch
        epoch = report.epoch
        profile = report.profile
        for leaf in report.watched + report.touched {
            leaves[leaf.id] = leaf
        }
        let settled = leaves.values.filter(\.stored).map(\.id).sorted()
        if moved { replaced += settled }
        for id in settled { leaves[id] = nil }
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
