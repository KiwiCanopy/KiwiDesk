import Foundation
import Testing

@testable import KiwiDeskCore

private let hyper: ScrollChord = [.control, .option]

/// The gesture binding list (#3199 ruling ▸ Storage, Families by
/// input, the action picker): a sparse map keyed by input and keys,
/// laid over real seeded rows, each action one of four kinds whose
/// Lua is the end key's value type.
@Suite("Gesture bindings")
struct GestureBindingTests {
    private func roundTrip(_ map: GestureMap) throws -> GestureMap {
        try JSONDecoder().decode(
            GestureMap.self,
            from: JSONEncoder().encode(map)
        )
    }

    @Test("a key spells its input and keys, and reads back")
    func keySpelling() {
        let key = GestureKey(.wheel, hyper)
        #expect(key.spelling == "wheel:control+option")
        #expect(GestureKey(spelling: key.spelling) == key)
        #expect(GestureKey(spelling: "tap4") == GestureKey(.tap4))
        #expect(GestureKey(spelling: "nose") == nil)
        #expect(GestureKey(spelling: "wheel:nonsense") == nil)
    }

    @Test("every action kind and a tombstone round-trip")
    func wire() throws {
        let lua = LuaAction(
            lua: "KiwiDesk.focus(\"left\")",
            kind: .navigation,
            meta: KeyBindingMeta(desc: "Left", group: "", symbol: "")
        )
        let map = GestureMap([
            GestureKey(.tap3): .unbound,
            GestureKey(.tap4, hyper): .bound(.run(lua)),
            GestureKey(.swipe2, hyper): .bound(.family(.focus)),
            GestureKey(.hoverMove, [.option]): .bound(
                .grab(.resize)
            ),
            GestureKey(.wheel, hyper): .bound(
                .split([.up: lua, .down: LuaAction(lua: "x()")])
            ),
        ])
        #expect(try roundTrip(map) == map)
    }

    @Test("an unknown key or an empty body fails the decode")
    func strict() {
        for json in [#"{"nose": null}"#, #"{"tap4": {}}"#] {
            #expect(throws: (any Error).self) {
                try JSONDecoder().decode(
                    GestureMap.self,
                    from: Data(json.utf8)
                )
            }
        }
    }

    @Test("the seeds are the ten default rows")
    func seeds() {
        let step: ScrollChord = [.control, .option, .command]
        let resolved = GestureSeeds.resolved(base: GestureMap(), profile: nil)
        #expect(resolved.count == 10)
        #expect(resolved[GestureKey(.swipe2, hyper)] == .family(.focus))
        #expect(resolved[GestureKey(.wheel, hyper)] == .family(.walk))
        #expect(resolved[GestureKey(.wheel, step)] == .family(.space))
        // A tilt wheel keeps 4.2.x's pan and Space step.
        #expect(resolved[GestureKey(.wheelX, hyper)] == .family(.walk))
        #expect(resolved[GestureKey(.wheelX, step)] == .family(.space))
        #expect(
            resolved[GestureKey(.drag, [.control, .command])]
                == .grab(.move)
        )
        #expect(
            resolved[GestureKey(.drag, hyper)] == .grab(.resize)
        )
        #expect(!resolved.keys.contains { $0.input == .hoverMove })
    }

    @Test("each Lua seed runs the Shortcuts catalogue's own Lua")
    func seedsAreRuled() {
        let catalogue = Set(
            DefaultKeybindings.bindings(
                spaces: [SpaceID("1")],
                resizeStep: 50,
                base: .standard
            ).map(\.lua)
        )
        for (key, action) in GestureSeeds.seeds {
            #expect(action.refusal(on: key) == nil, "\(key.spelling)")
            guard case .run(let lua) = action else { continue }
            #expect(catalogue.contains(lua.lua), "\(key.spelling)")
        }
    }

    @Test("a grab starts on a press for drag, on the keys for hover_move")
    @MainActor
    func grabStart() {
        let settings = KiwiCore.grabSettings([
            GestureKey(.drag, [.control, .command]): .grab(.move),
            GestureKey(.hoverMove, hyper): .grab(.resize),
        ])
        #expect(
            settings.bindings == [
                ModifierDragBinding(.move, chord: [.control, .command]),
                ModifierDragBinding(.resize, chord: hyper, start: .hover),
            ]
        )
    }

    @Test("the base lies over the seeds, a profile over the base")
    func layering() {
        let base = GestureMap([GestureKey(.tap3): .unbound])
        let profile = GestureMap([
            GestureKey(.tap3): .bound(.run(LuaAction(lua: "p()"))),
            GestureKey(.tap4): .unbound,
        ])
        let resolved = GestureSeeds.resolved(base: base, profile: profile)
        #expect(resolved[GestureKey(.tap3)] == .run(LuaAction(lua: "p()")))
        #expect(resolved[GestureKey(.tap4)] == nil)
        #expect(
            GestureSeeds.resolved(base: base, profile: nil)[
                GestureKey(.tap3)
            ] == nil
        )
    }

    @Test(
        "each refusal names its rule",
        arguments: [
            (
                GestureKey(.wheel, [.control]), GestureAction.family(.walk),
                GestureRefusal.singleModifierScroll
            ),
            (
                GestureKey(.wheel, [.control, .shift]), .family(.walk),
                .shiftOnWheel
            ),
            (GestureKey(.wheel, hyper), .family(.focus), .familyNotOffered),
            (
                GestureKey(.click, hyper), .grab(.move),
                .grabOnlyOnDrag
            ),
            (GestureKey(.drag, hyper), .family(.focus), .grabOnlyOnDrag),
            (
                GestureKey(.swipe2, hyper), .run(LuaAction(lua: "x()")),
                .directionalNeedsFamily
            ),
            (
                GestureKey(.click, hyper),
                .split([.up: LuaAction(lua: "x()")]),
                .noDirections
            ),
            (GestureKey(.click), .run(LuaAction(lua: "x()")), .needsModifier),
            (GestureKey(.tap4), .run(LuaAction(lua: " ")), .emptyAction),
        ]
    )
    func refusals(
        key: GestureKey,
        action: GestureAction,
        refusal: GestureRefusal
    ) {
        #expect(action.refusal(on: key) == refusal)
    }

    @Test("a drag's keys keep a click on them silent")
    func dragHoldsItsKeys() {
        let keys: ScrollChord = [.control, .command]
        let base = GestureMap([
            GestureKey(.click, keys): .bound(.run(LuaAction(lua: "x()"))),
            GestureKey(.click, [.shift, .command]): .bound(
                .run(LuaAction(lua: "y()"))
            ),
        ])
        let resolved = GestureSeeds.resolved(base: base, profile: nil)
        #expect(resolved[GestureKey(.click, keys)] == nil)
        #expect(resolved[GestureKey(.click, [.shift, .command])] != nil)
    }

    @Test("an empty split binds nothing")
    func emptySplit() {
        #expect(GestureAction.split(normalizing: [:]) == nil)
        #expect(
            GestureAction.split(normalizing: [.up: LuaAction(lua: "x()")])
                == .split([.up: LuaAction(lua: "x()")])
        )
    }

    /// A gesture row codes the meta by hand beside the end key's
    /// coder (parity-tests.md): every field `KeyBindingMeta` stores
    /// must reach the wire, or a new one drops on a gesture row.
    @Test("every meta field reaches a gesture row's wire")
    func metaFieldsReachTheWire() throws {
        let labels = Set(
            Mirror(reflecting: KeyBindingMeta()).children.compactMap(\.label)
        )
        #expect(labels.count >= 3)
        let action = LuaAction(
            lua: "x()",
            meta: KeyBindingMeta(desc: "d", group: "g", symbol: "s")
        )
        let data = try JSONEncoder().encode(action)
        let object = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        #expect(Set(object.keys).subtracting(["lua", "kind"]) == labels)
    }

    @Test("two actions in one body, or an empty table, fail the decode")
    func oneActionPerBody() {
        for json in [
            #"{"tap4": {"family": "focus", "grab": "move"}}"#,
            #"{"tap4": {"family": "focus", "lua": "x()"}}"#,
            #"{"tap4": {"lua": "x()", "bogus": 1}}"#,
            #"{"wheel:control+option": {"split": {}}}"#,
            #"{"tap4:": null}"#,
            #"{"wheel:option+control": null}"#,
        ] {
            #expect(throws: (any Error).self, "\(json)") {
                try JSONDecoder().decode(
                    GestureMap.self,
                    from: Data(json.utf8)
                )
            }
        }
    }

    @Test("an end key's action is its own three halves")
    func keyBindingAction() {
        var binding = KeyBinding(combo: "alt+h", lua: "a()", kind: .custom)
        binding.action = LuaAction(
            lua: "b()",
            kind: .navigation,
            meta: KeyBindingMeta(desc: "B", group: "g", symbol: "star")
        )
        #expect(binding.lua == "b()")
        #expect(binding.kind == .navigation)
        #expect(binding.meta.desc == "B")
        #expect(binding.action.meta.symbol == "star")
        #expect(binding.combo == "alt+h")
    }
}
