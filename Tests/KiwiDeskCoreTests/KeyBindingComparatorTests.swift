import Foundation
import Testing

@testable import KiwiDeskCore

/// Comparator-contract parity net (AGENTS.md §5): KeyBinding's
/// field list is hand-mirrored across CodingKeys /
/// `init(from:)` / `encode` / `==` / `sameAction`. Two
/// equality notions coexist deliberately — `==` is
/// persisted-value identity (drives the gui.json dirty
/// check), `sameAction` is cascade identity (combo + lua;
/// display metadata never reads as profile divergence). These
/// tests force a conscious which-notion decision when a field
/// is added, instead of a silent default.
@Suite("KeyBinding comparator contract (#55)")
struct KeyBindingComparatorTests {

    private let row = KeyBinding(
        combo: "alt+h",
        lua: "focus_left",
        kind: .custom,
        label: "Focus left"
    )

    @Test("== distinguishes every persisted field")
    func fullEqualityDistinguishesEachField() {
        var combo = row
        combo.combo = "alt+j"
        #expect(combo != row)

        var lua = row
        lua.lua = "focus_right"
        #expect(lua != row)

        var kind = row
        kind.kind = .navigation
        #expect(kind != row)

        var label = row
        label.label = "Other"
        #expect(label != row)

        #expect(row == row)
    }

    @Test("sameAction distinguishes exactly combo + lua")
    func sameActionIsComboPlusLuaOnly() {
        var combo = row
        combo.combo = "alt+j"
        #expect(!combo.sameAction(as: row))

        var lua = row
        lua.lua = "focus_right"
        #expect(!lua.sameAction(as: row))

        // Display metadata must NOT read as divergence.
        var kind = row
        kind.kind = .navigation
        #expect(kind.sameAction(as: row))

        var label = row
        label.label = "Other"
        #expect(label.sameAction(as: row))
    }

    /// Forget-proof net: a NEW stored property fails this
    /// count first — add it to CodingKeys, `init(from:)`,
    /// `encode`, `==`, and DECIDE whether `sameAction` sees
    /// it, then update the count here last.
    @Test("Stored-property count pins the mirrored field list")
    func storedPropertyCount() {
        let children = Mirror(reflecting: row).children
        // id + combo + lua + kind + label
        #expect(children.count == 5)
    }
}
