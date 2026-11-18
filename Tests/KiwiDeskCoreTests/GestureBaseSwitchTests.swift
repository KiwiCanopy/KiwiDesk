import Foundation
import Testing

@testable import KiwiDeskCore

/// The gesture rows on the "Shortcuts use" base (#3444): the drags
/// share one base, the seeds sit on the stored base, and the switch
/// moves a stored row with the keyboard rows' mapping.
@Suite("Gesture rows follow the shortcut base")
@MainActor
struct GestureBaseSwitchTests {
    private let pan: ScrollChord = [.control, .option]
    private let hyper: ScrollChord = [.hyper]

    @Test("⌃⌥ drag moves and ⌃⌥⇧ drag resizes")
    func dragSeeds() {
        let seeds = GestureSeeds.seeds(on: .standard)
        #expect(seeds[GestureKey(.drag, pan)] == .grab(.move))
        #expect(
            seeds[GestureKey(.drag, pan.union(.shift))] == .grab(.resize)
        )
        #expect(seeds[GestureKey(.drag, [.control, .command])] == nil)
    }

    @Test("on ✦ every ⌃⌥ seed sits on ✦, ⇧ and ⌘ kept")
    func hyperSeeds() {
        let standard = GestureSeeds.seeds(on: .standard)
        let seeds = GestureSeeds.seeds(on: .hyper)
        #expect(seeds.count == standard.count)
        #expect(seeds[GestureKey(.drag, hyper)] == .grab(.move))
        #expect(
            seeds[GestureKey(.drag, hyper.union(.shift))] == .grab(.resize)
        )
        #expect(
            seeds[GestureKey(.swipe2, hyper.union(.command))]
                == .family(.space)
        )
        #expect(seeds[GestureKey(.tap3)] == standard[GestureKey(.tap3)])
        #expect(!seeds.keys.contains { $0.chord.isSuperset(of: pan) })
    }

    @Test("the chord mapping is the keyboard rows', both ways")
    func chordMapping() {
        let shifted: ScrollChord = [.control, .option, .shift]
        #expect(ShortcutBase.moved(shifted, to: .hyper) == [.hyper, .shift])
        #expect(
            ShortcutBase.moved([.hyper, .shift], to: .standard) == shifted
        )
        #expect(ShortcutBase.moved([.control, .command], to: .hyper) == nil)
        #expect(ShortcutBase.moved(pan, to: .standard) == nil)
        #expect(ShortcutBase.moved([], to: .hyper) == nil)
    }

    @Test("a stored row and a tombstone move with the switch")
    func storedRowsMove() {
        let mine = GestureKey(.wheel, pan.union(.shift))
        var map = GestureMap()
        map[mine] = .bound(.family(.space))
        map[GestureKey(.swipe2, pan)] = .unbound
        let moved = GestureBaseSwitch.move(map, from: .standard, onto: .hyper)
        #expect(moved.kept.isEmpty)
        #expect(
            moved.map[GestureKey(.wheel, hyper.union(.shift))]
                == .bound(.family(.space))
        )
        #expect(moved.map[GestureKey(.swipe2, hyper)] == .unbound)
        #expect(moved.map[mine] == nil)
        let before = GestureSeeds.resolved(
            base: map,
            profile: nil,
            shortcutBase: .standard
        )
        let after = GestureSeeds.resolved(
            base: moved.map,
            profile: nil,
            shortcutBase: .hyper
        )
        let rebased = Dictionary(
            uniqueKeysWithValues: before.map {
                (ShortcutBase.hyper.rebased($0.key), $0.value)
            }
        )
        #expect(after == rebased)
    }

    @Test("the way back reverses the move")
    func roundTrip() {
        var map = GestureMap()
        map[GestureKey(.wheel, pan.union(.command))] = .bound(.family(.walk))
        map[GestureKey(.tap3)] = .unbound
        map[GestureKey(.drag, pan)] = .bound(.grab(.resize))
        let there = GestureBaseSwitch.move(map, from: .standard, onto: .hyper)
        let back = GestureBaseSwitch.move(
            there.map,
            from: .hyper,
            onto: .standard
        )
        #expect(back.map == map)
    }

    /// A row of the user's on ✦ drag holds the seed's new key, so
    /// the seed stays on ⌃⌥, written into the file and named.
    @Test("a seed whose ✦ key a row holds is pinned on ⌃⌥")
    func heldTargetPins() {
        var map = GestureMap()
        map[GestureKey(.drag, hyper)] = .bound(.grab(.resize))
        let moved = GestureBaseSwitch.move(map, from: .standard, onto: .hyper)
        let old = GestureKey(.drag, pan)
        #expect(moved.map[old] == .bound(.grab(.move)))
        #expect(
            moved.kept == [
                GestureBaseSwitch.Kept(
                    key: old,
                    target: GestureKey(.drag, hyper),
                    holder: GestureKey(.drag, hyper)
                )
            ]
        )
        let resolved = GestureSeeds.resolved(
            base: moved.map,
            profile: nil,
            shortcutBase: .hyper
        )
        #expect(resolved[GestureKey(.drag, hyper)] == .grab(.resize))
        #expect(resolved[old] == .grab(.move))
    }

    @Test("a profile's override resolves as it did after the move")
    func profileFollows() {
        let base = GestureMap()
        var profile = GestureMap()
        profile[GestureKey(.drag, pan)] = .unbound
        profile[GestureKey(.wheel, pan)] = .bound(.family(.space))
        profile[GestureKey(.pinchTogether, hyper)] = .bound(
            .run(LuaAction(lua: "x()"))
        )
        let moved = GestureBaseSwitch.move(base, from: .standard, onto: .hyper)
        let following = profile.following(moved.moves)
        let before = GestureSeeds.resolved(
            base: base,
            profile: profile,
            shortcutBase: .standard
        )
        let after = GestureSeeds.resolved(
            base: moved.map,
            profile: following,
            shortcutBase: .hyper
        )
        #expect(after[GestureKey(.drag, hyper)] == nil)
        // The profile's own wheel row stays where the profile put it.
        #expect(after[GestureKey(.wheel, pan)] == .family(.space))
        #expect(after[GestureKey(.wheel, hyper)] == nil)
        #expect(before[GestureKey(.pinchTogether, pan)] != nil)
        // A base row the profile's own ✦ row replaces stays on ⌃⌥.
        #expect(
            after[GestureKey(.pinchTogether, hyper)]
                == .run(LuaAction(lua: "x()"))
        )
        #expect(
            after[GestureKey(.pinchTogether, pan)]
                == before[GestureKey(.pinchTogether, pan)]
        )
    }

    @Test("the switch moves the draft's gesture map with its rows")
    func switchMovesGestures() {
        var config = GuiConfig()
        config.gesture[GestureKey(.swipe2, pan)] = .unbound
        ShortcutBaseSwitch.apply(.hyper, to: &config)
        #expect(config.shortcutBase == .hyper)
        #expect(config.gesture[GestureKey(.swipe2, hyper)] == .unbound)
        #expect(config.gesture[GestureKey(.swipe2, pan)] == nil)
    }

    @Test("a load on ✦ grabs on ✦ drag")
    func loadReadsTheBase() throws {
        let core = makeTestCore(
            configDirectory: testTemporaryDirectory.appendingPathComponent(
                "kiwi-gesture-base-\(UUID().uuidString)"
            )
        )
        try FileManager.default.createDirectory(
            at: core.configDirectory,
            withIntermediateDirectories: true
        )
        var config = GuiConfig()
        config.shortcutBase = .hyper
        try core.guiConfigStore.save(config)
        core.loadConfig()
        #expect(core.isGuiManaged)
        let resolved = core.mouse.gestures.resolved
        #expect(resolved[GestureKey(.drag, hyper)] == .grab(.move))
        #expect(resolved[GestureKey(.drag, pan)] == nil)
        #expect(
            core.mouse.pointer.grabSettings.grabs.contains {
                $0.chord == hyper && $0.action == .move
            }
        )
    }
}
