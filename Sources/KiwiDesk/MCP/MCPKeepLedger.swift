import Foundation
import KiwiDeskCore

/// The live changes this MCP session made and has not kept
/// (#1685 ▸ Ruling 4): what Core's change reports said of the
/// leaves this session touched — never a diff or a verdict of its
/// own. Every request asks Core to judge them again (`watch`):
/// a leaf Core calls stored is no longer pending, and one whose
/// value moved away from the session's was replaced. One per server,
/// read and written on its one request loop.
final class MCPKeepLedger {
    /// Core's latest verdict on every leaf still outstanding, by id.
    private var leaves: [String: TouchedLeaf] = [:]
    /// The value this session last set on each leaf, by id.
    private var ownValues: [String: JSONValue?] = [:]
    private var profile: String?
    /// Ids something else changed before a keep, told once.
    private var replaced: [String] = []

    /// The ids a request asks Core to judge.
    var watch: [String] { leaves.keys.sorted() }

    /// Takes in one answer's report. A leaf whose live value is no
    /// longer the one this session set was replaced — a load, a
    /// reload, Settings or another tool — and is told once and
    /// forgotten; a leaf Core calls stored with this session's
    /// value was kept — a keep, a Save or a set-back — and leaves
    /// silently. A `replacing` request — a command Core registers
    /// destructive, such as a load — sets no value of the
    /// session's: what it touched is judged like any other change.
    func absorb(_ report: ChangeReport, replacing: Bool = false) {
        profile = report.profile
        if !replacing {
            for leaf in report.touched {
                leaves[leaf.id] = leaf
                ownValues[leaf.id] = .some(leaf.value)
            }
        }
        let judged =
            replacing ? report.touched + report.watched : report.watched
        for leaf in judged where leaves[leaf.id] != nil {
            if let mine = ownValues[leaf.id], mine != leaf.value {
                replaced.append(leaf.id)
                forget(leaf.id)
            } else {
                leaves[leaf.id] = leaf
            }
        }
        for leaf in leaves.values where leaf.stored { forget(leaf.id) }
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
    /// unkeepable ones — once where no later state lifts the
    /// refusal — and, once, what was replaced. Nil where there is
    /// nothing to say.
    func status() -> (text: String, structure: JSONValue)? {
        let pending = pending
        let refused = refused
        let replaced = replaced
        self.replaced = []
        // A refusal no later state lifts is told once, then dropped.
        for leaf in refused
        where !(leaf.notKeepable?.isLiftable ?? true) {
            forget(leaf.id)
        }
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
            "live_not_kept": .array(pending.map(\.json)),
            "not_keepable": .array(refused.map(\.json)),
        ]
        if let profile { fields["profile"] = .string(profile) }
        if !replaced.isEmpty {
            fields["replaced"] = .array(replaced.map(JSONValue.string))
        }
        return (lines.joined(separator: "\n"), .object(fields))
    }
}
