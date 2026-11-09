import Foundation
import Testing

@testable import KiwiDeskCore

/// A key sequence in the key reach table (#3124): keyed by its layer
/// and leader, its value the whole tree, written back whole — since
/// a profile holds or overrides a sequence whole (#1871).
@Suite("Rule reach, key sequences (#3124)")
struct RuleReachSequenceKeyTests {
    private typealias Table = RuleReachTable<String>
    private let left = "KiwiDesk.focus(\"left\")"
    private let leader = "ctrl+alt+space"

    private func tree(_ label: String = "Leader") -> KeyBinding {
        .sequence(
            combo: leader,
            label: label,
            steps: [KeyBinding(combo: "h", lua: left, kind: .navigation)]
        )
    }

    private var key: String {
        Table.sequenceID(layer: "default", leader: leader)
    }

    private func layers(_ rows: [KeyBinding]) -> [KeyLayer] {
        [KeyLayer(name: "default", bindings: rows)]
    }

    private func table(
        base: [KeyBinding],
        home: KeyLayerOverride? = nil
    ) -> Table {
        .keyLayers(
            base: layers(base),
            overrides: [("Work", nil), ("Home", home)]
        )
    }

    @Test("a sequence is named by its leader, its tree the value")
    func namedByLeader() throws {
        let combos = Table.combos(layers([tree()]))
        let value = try #require(combos[key])
        #expect(combos.count == 1)
        #expect(Table.leader(of: key) == leader)
        #expect(Table.chord(of: key, value: value) == leader)
        #expect(Table.sequenceTree(value) == tree())
        // No row id rides the value, so two copies of a tree agree.
        #expect(Table.value(of: tree()) == Table.value(of: tree()))
        // An unrecorded leader names no key.
        #expect(Table.combos(layers([.sequence(combo: "")])).isEmpty)
    }

    @Test("a profile's own tree is its entry, written back whole")
    func ownTreeRoundTrips() throws {
        let home = KeyLayerOverride(layers: layers([tree("Mine")]))
        var t = table(base: [tree()], home: home)
        let mine = Table.sequenceTree(t.resolved(key, for: "Home") ?? "")
        #expect(mine == tree("Mine"))
        t.apply(
            key,
            value: Table.value(of: tree("Home's")),
            reach: .listed(["Home"]),
            editing: "Home"
        )
        let written = t.keyLayerOverride(
            for: "Home",
            original: home,
            newBase: layers([tree()]),
            templates: [:]
        )
        let resolved = written?.resolved(onto: layers([tree()]))
        #expect(resolved?.first?.sequences == [tree("Home's")])
        #expect(t.base[key] == Table.value(of: tree()))
    }

    @Test("writing one sequence leaves the layer's others alone")
    func otherSequencesStay() {
        let other = KeyBinding.sequence(combo: "ctrl+alt+b", label: "B")
        var rows = layers([tree(), other])
        Table.setRows(&rows, key, [Table.value(of: tree("New"))], nil)
        #expect(rows.first?.sequences == [tree("New"), other])
        Table.setRows(&rows, key, [], nil)
        #expect(rows.first?.sequences == [other])
    }

    @Test("a profile's own row on the leader keeps it from a shared tree")
    func ownRowOnTheLeaderKeeps() {
        let home = KeyLayerOverride(
            layers: layers([KeyBinding(combo: leader, lua: left)])
        )
        var t = table(base: [], home: home)
        t.applyKey(
            key,
            value: Table.value(of: tree()),
            reach: .shared(joining: []),
            editing: "Work"
        )
        #expect(t.resolved(key, for: "Home") == nil)
        let row = Table.keyID(layer: "default", lua: left)
        #expect(t.resolved(row, for: "Home") == leader)
        #expect(t.rival(of: key, for: "Home", combo: leader) == row)
        #expect(
            KeyRivals(t).rival(of: key, for: "Home", combo: leader) == row
        )
    }
}
