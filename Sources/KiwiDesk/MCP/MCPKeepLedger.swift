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
    /// The value this session last set on each leaf, by id.
    private var ownValues: [String: JSONValue?] = [:]
    /// The epoch of the latest report; a keep sends it back.
    private(set) var epoch: String?
    private var profile: String?
    /// Pending ids something else replaced, told once.
    private var replaced: [String] = []

    /// Refusals another state can lift, so Core judges them again.
    private static let rejudged: Set<NotKeepable> = [
        .temporarySpace, .notWritten, .conflicting,
    ]

    /// The ids a request asks Core to judge: the pending leaves
    /// and the refusals another state can lift.
    var watch: [String] {
        leaves.values.filter {
            $0.notKeepable.map(Self.rejudged.contains) ?? true
        }.map(\.id).sorted()
    }

    /// Takes in one answer's report. A leaf Core now calls stored
    /// leaves the ledger: told nothing where its live value is the
    /// one this session set — a keep, a Save or a set-back stored
    /// it — and told as replaced where something else put another
    /// value there. A moved epoch also ends the refusals no keep
    /// could lift, since the load reset what they named.
    func absorb(_ report: ChangeReport) {
        if let epoch, epoch != report.epoch {
            for leaf in refused
            where !(leaf.notKeepable.map(Self.rejudged.contains) ?? false) {
                forget(leaf.id)
            }
        }
        epoch = report.epoch
        profile = report.profile
        for leaf in report.touched {
            leaves[leaf.id] = leaf
            ownValues[leaf.id] = .some(leaf.value)
        }
        for leaf in report.watched where leaves[leaf.id] != nil {
            leaves[leaf.id] = leaf
        }
        for leaf in leaves.values.filter(\.stored) {
            if let mine = ownValues[leaf.id], mine != leaf.value {
                replaced.append(leaf.id)
            }
            forget(leaf.id)
        }
        replaced.sort()
    }

    private func forget(_ id: String) {
        leaves[id] = nil
        ownValues[id] = nil
    }

    /// Ends the leaves a keep wrote, and takes the verdict it gave
    /// for any it could not.
    func settle(kept: [String], refused: [TouchedLeaf]) {
        for id in kept { forget(id) }
        for leaf in refused where leaves[leaf.id] != nil {
            leaves[leaf.id] = leaf
        }
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
