import Foundation
import Testing

@testable import KiwiDeskCore

private let pan: ScrollChord = [.control, .option]

/// Gestures bind per keybinding layer (#3535 ▸ Ruling 1): only the
/// active layer's map resolves, a layer other than `default` lies
/// over no seeds, and `gesture.bind` takes the layer last.
@Suite("Layer gesture resolve (#3535)")
@MainActor
struct LayerGestureResolveTests {
    private let swipe = GestureKey(.swipe3, pan)

    @Test("a layer other than default lies over no seeds")
    func noFallThrough() {
        let seeds = GestureSeeds.seeds(on: .standard)
        #expect(!seeds.isEmpty)
        #expect(
            GestureSeeds.seeds(on: .standard, layer: "default") == seeds
        )
        #expect(GestureSeeds.seeds(on: .standard, layer: "Coding").isEmpty)
        let resolved = GestureSeeds.resolved(
            base: GestureMap(),
            profile: nil,
            shortcutBase: .standard,
            layer: "Coding"
        )
        #expect(resolved.isEmpty)
    }

    @Test("a layer switch resolves the new layer's map alone")
    func switchResolves() {
        let core = makeTestCore()
        core.keys.defineLayer("Coding", bindings: [:])
        let bound = core.execute(
            "gesture.bind",
            args: [
                .string("swipe3"), .string("control+option"),
                .string("space"), .string("Coding"),
            ]
        )
        #expect(bound.isSuccess)
        // The default layer still resolves its seed there.
        #expect(core.mouse.gestures.layer == "default")
        #expect(core.mouse.gestures.resolved[swipe] != .family(.space))
        core.keys.switchLayer("Coding")
        #expect(core.mouse.gestures.layer == "Coding")
        #expect(core.mouse.gestures.resolved == [swipe: .family(.space)])
        core.keys.switchLayer("default")
        #expect(
            core.mouse.gestures.resolved
                == GestureSeeds.resolved(
                    base: GestureMap(),
                    profile: nil,
                    shortcutBase: .standard,
                    layer: "default"
                )
        )
    }

    @Test("bind without a layer writes default's, unbind takes one")
    func verbLayers() {
        let core = makeTestCore()
        #expect(
            core.execute(
                "gesture.bind",
                args: [
                    .string("tap5"), .string(""), .string("x()"),
                ]
            ).isSuccess
        )
        #expect(
            core.mouse.gestures.base["default"][GestureKey(.tap5)]
                == .bound(.run(LuaAction(lua: "x()")))
        )
        #expect(
            core.execute(
                "gesture.unbind",
                args: [.string("tap5"), .string(""), .string("Coding")]
            ).isSuccess
        )
        #expect(
            core.mouse.gestures.base["Coding"][GestureKey(.tap5)]
                == .unbound
        )
        #expect(
            !core.execute(
                "gesture.bind",
                args: [
                    .string("tap5"), .string(""), .string("x()"),
                    .string(""),
                ]
            ).isSuccess
        )
    }

    @Test("a layer key spells default bare and reads every layer back")
    func keySpelling() {
        let bare = LayerGestureKey("default", swipe)
        #expect(bare.spelling == swipe.spelling)
        #expect(LayerGestureKey(spelling: bare.spelling) == bare)
        let coding = LayerGestureKey("Coding / Work", swipe)
        #expect(coding.spelling != swipe.spelling)
        #expect(LayerGestureKey(spelling: coding.spelling) == coding)
        #expect(LayerGestureKey(spelling: "nose") == nil)
    }

    @Test("rename carries a layer's map, delete drops it, empty leaves")
    func layerEdits() {
        let map = GestureMap([swipe: .bound(.family(.space))])
        let maps = LayerGestures(["default": map, "Coding": map])
        #expect(
            maps.renaming("Coding", to: "Code").layers == [
                "Code", "default",
            ]
        )
        #expect(maps.removing("Coding").layers == ["default"])
        var edited = maps
        edited["Coding"] = GestureMap()
        #expect(edited.layers == ["default"])
    }

    @Test("a profile's override lies over its own layer's base")
    func overlayPerLayer() {
        let base = LayerGestures([
            "Coding": GestureMap([swipe: .bound(.family(.space))])
        ])
        let profile = LayerGestures([
            "Coding": GestureMap([swipe: .unbound])
        ])
        #expect(base.overlaid(by: profile)["Coding"][swipe] == .unbound)
        #expect(
            LayerGestures.diff(
                base: base,
                edited: base.overlaid(by: profile),
                shortcutBase: .standard
            ) == profile
        )
    }
}
