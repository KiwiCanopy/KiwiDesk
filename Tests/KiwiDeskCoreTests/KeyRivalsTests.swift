import Testing

@testable import KiwiDeskCore

/// `KeyRivals` answers `RuleReachTable.rival` from one index over the
/// table, so a page of shortcut rows stops scanning every key per row
/// and profile (#2783). The index is only safe while it answers what
/// the scan answers, so each case asks both over every key, profile
/// and combo the table holds.
@Suite("Shortcut rivals answer from one index")
struct KeyRivalsTests {
    private typealias Table = RuleReachTable<String>

    private func key(_ layer: String, _ lua: String) -> String {
        Table.keyID(layer: layer, lua: lua)
    }

    /// Two layers, a base, overrides that rebind, add and leave out.
    private var table: Table {
        Table(
            base: [
                key("Default", "a()"): "alt+a",
                key("Default", "b()"): "alt+b",
                key("Default", "c()"): "alt+a",
                key("Gaming", "a()"): "alt+a",
            ],
            entries: [
                "Work": [
                    key("Default", "b()"): "alt+a",
                    key("Default", "d()"): "alt+d",
                ],
                "Home": [
                    key("Default", "a()"): nil,
                    key("Gaming", "e()"): "alt+a",
                ],
            ],
            profiles: ["Work", "Home", "Travel"]
        )
    }

    /// Every (key, profile, combo) a row could ask about.
    private func asks(_ table: Table) -> [(String, String, String)] {
        let keys = Set(table.base.keys)
            .union(table.entries.values.flatMap(\.keys))
        let combos = Set(table.base.values)
            .union(
                table.entries.values.flatMap { $0.values.compactMap { $0 } }
            )
            .union(["ctrl+z"])
        return keys.flatMap { key in
            table.profiles.flatMap { profile in
                combos.map { (key, profile, $0) }
            }
        }
    }

    @Test("Every ask answers what the scan answers")
    func matchesTheScan() {
        let table = table
        let rivals = KeyRivals(table)
        var found = 0
        for (key, profile, combo) in asks(table) {
            let scan = table.rival(of: key, for: profile, combo: combo)
            #expect(
                rivals.rival(of: key, for: profile, combo: combo) == scan,
                "\(key) \(profile) \(combo)"
            )
            if scan != nil { found += 1 }
        }
        #expect(found > 0)
    }

    @Test("A key is never its own rival, and layers stay apart")
    func ownKeyAndLayer() {
        let rivals = KeyRivals(table)
        let a = key("Default", "a()")
        // c() shares a()'s combo in the base; Gaming's a() does not
        // count, being another layer.
        #expect(
            rivals.rival(of: a, for: "Travel", combo: "alt+a")
                == key("Default", "c()")
        )
        #expect(
            rivals.rival(
                of: key("Gaming", "a()"),
                for: "Travel",
                combo: "alt+a"
            ) == nil
        )
        // Home leaves a() out, so its combo is c()'s alone.
        #expect(
            rivals.rival(
                of: key("Default", "c()"),
                for: "Home",
                combo: "alt+a"
            ) == nil
        )
    }
}
