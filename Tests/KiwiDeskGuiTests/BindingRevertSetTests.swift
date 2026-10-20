import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The set one shortcut row's ↺ takes back (#2412): the binding and
/// every changed binding of its layer a chord was moved to or from,
/// either side of the move, never an unchanged one or another
/// layer's. Pure: no model, no host state.
@Suite("Binding revert set (#2412)")
struct BindingRevertSetTests {
    private func layer(
        _ rows: [(String, String)],
        named name: String = KeyLayer.defaultName
    ) -> KeyLayer {
        KeyLayer(
            name: name,
            bindings: rows.map { KeyBinding(combo: $0.1, lua: $0.0) }
        )
    }

    private func walk(
        _ lua: String,
        _ draft: [KeyLayer],
        _ saved: [KeyLayer],
        in name: String = KeyLayer.defaultName
    ) -> [String] {
        BindingRevertSet.walk(
            layer: name,
            saved: name,
            lua: lua,
            draft: draft,
            baseline: saved
        )
    }

    @Test("a plain rebind takes itself alone")
    func plainRebind() {
        let saved = [layer([("a", "ctrl+h"), ("b", "ctrl+j")])]
        let draft = [layer([("a", "ctrl+k"), ("b", "ctrl+j")])]
        #expect(walk("a", draft, saved) == ["a"])
    }

    /// c is rebound too, to a chord nobody had: not a's to take.
    @Test("an unrelated change in the layer stays")
    func unrelatedChangeStays() {
        let saved = [layer([("a", "ctrl+h"), ("c", "ctrl+k")])]
        let draft = [layer([("a", "ctrl+y"), ("c", "ctrl+z")])]
        #expect(walk("a", draft, saved) == ["a"])
        let back = BindingRevertSet.restore(
            ["a"],
            layer: KeyLayer.defaultName,
            saved: KeyLayer.defaultName,
            draft: draft,
            baseline: saved
        )
        #expect(back[0].bindings.map(\.combo) == ["ctrl+h", "ctrl+z"])
    }

    /// A renamed layer is read under its saved name.
    @Test("a renamed layer reads its saved rows")
    func renamedLayerReadsSaved() {
        let saved = [layer([("a", "ctrl+h")], named: "Gaming")]
        let draft = [layer([("a", "ctrl+y")], named: "Play")]
        let back = BindingRevertSet.restore(
            ["a"],
            layer: "Play",
            saved: "Gaming",
            draft: draft,
            baseline: saved
        )
        #expect(back[0].bindings.map(\.combo) == ["ctrl+h"])
    }

    /// A Space verb spelled another way is the same action: the
    /// restore leaves it no second chord.
    @Test("a restore drops another spelling of the action")
    func restoreDropsOtherSpelling() {
        let saved = [layer([("KiwiDesk.focus_space(\"2\")", "ctrl+2")])]
        let draft = [layer([("KiwiDesk.focus_space(2)", "ctrl+9")])]
        let back = BindingRevertSet.restore(
            ["KiwiDesk.focus_space(\"2\")"],
            layer: KeyLayer.defaultName,
            saved: KeyLayer.defaultName,
            draft: draft,
            baseline: saved
        )
        #expect(back == saved)
    }

    /// The recorder moved ctrl+h from a to b: either ↺ takes both.
    @Test("a move reverts from either side")
    func moveRevertsBoth() {
        let saved = [layer([("a", "ctrl+h"), ("b", "ctrl+j")])]
        let draft = [layer([("b", "ctrl+h")])]
        #expect(walk("a", draft, saved) == ["a", "b"])
        #expect(walk("b", draft, saved) == ["b", "a"])
        let back = BindingRevertSet.restore(
            ["a", "b"],
            layer: KeyLayer.defaultName,
            saved: KeyLayer.defaultName,
            draft: draft,
            baseline: saved
        )
        #expect(back == saved)
    }

    /// a's chord to b, b's to c: the whole chain, from any link.
    @Test("a chain reverts whole")
    func chainRevertsWhole() {
        let saved = [
            layer([("a", "ctrl+h"), ("b", "ctrl+j"), ("c", "ctrl+k")])
        ]
        let draft = [layer([("b", "ctrl+h"), ("c", "ctrl+j")])]
        #expect(Set(walk("a", draft, saved)) == ["a", "b", "c"])
        #expect(Set(walk("c", draft, saved)) == ["a", "b", "c"])
        #expect(walk("a", draft, saved).first == "a")
    }

    /// d holds a's saved chord as saved too: unchanged, it stays.
    @Test("an unchanged binding is never taken")
    func unchangedStays() {
        let saved = [layer([("a", "ctrl+h"), ("d", "ctrl+h")])]
        let draft = [layer([("d", "ctrl+h")])]
        #expect(walk("a", draft, saved) == ["a"])
    }

    @Test("another layer's binding is never taken")
    func otherLayerStays() {
        let saved = [
            layer([("a", "ctrl+h")]),
            layer([("b", "ctrl+j")], named: "Gaming"),
        ]
        let draft = [
            layer([] as [(String, String)]),
            layer([("b", "ctrl+h")], named: "Gaming"),
        ]
        #expect(walk("a", draft, saved) == ["a"])
        #expect(walk("b", draft, saved, in: "Gaming") == ["b"])
    }

    @Test("a restore puts each row at its saved place")
    func restoreKeepsPlace() {
        let saved = [layer([("a", "1"), ("b", "2"), ("c", "3")])]
        let draft = [layer([("a", "1"), ("c", "3"), ("x", "9")])]
        let back = BindingRevertSet.restore(
            ["b"],
            layer: KeyLayer.defaultName,
            saved: KeyLayer.defaultName,
            draft: draft,
            baseline: saved
        )
        #expect(back[0].bindings.map(\.lua) == ["a", "b", "c", "x"])
    }

    @Test("a binding of a layer the baseline lacks goes")
    func newLayerRowGoes() {
        let draft = [layer([("a", "1")], named: "New")]
        let back = BindingRevertSet.restore(
            ["a"],
            layer: "New",
            saved: "New",
            draft: draft,
            baseline: []
        )
        #expect(back[0].bindings.isEmpty)
    }
}
