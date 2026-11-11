import Foundation
import Testing

@testable import KiwiDeskCore

/// The fold of the fixed gesture settings into the binding list
/// (#3199, `migratingGesturesIntoBindings`), through
/// `ConfigMigration.migrated` from the formats the last release
/// shipped. Each fixture is the real encoder's file, re-stamped to
/// that format, with the retired keys spelled by hand on top, since
/// their types are gone with the step.
@Suite("Gesture binding migration")
struct GestureMigrationTests {
    private func object(_ json: String) throws -> [String: Any] {
        try #require(
            JSONSerialization.jsonObject(with: Data(json.utf8))
                as? [String: Any]
        )
    }

    /// A file of `format` from the real encoder, the retired keys
    /// `old` spells laid on top: the old types are gone, the
    /// envelope is not.
    private func envelope(
        _ data: Data,
        format: Int,
        _ old: String
    ) throws -> [String: Any] {
        var root = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        root["format"] = format
        root.merge(try object(old)) { _, new in new }
        return root
    }

    /// A gui.json the last release shipped.
    private func gui(_ old: String) throws -> [String: Any] {
        try envelope(JSONEncoder().encode(GuiConfig()), format: 20, old)
    }

    /// A profile file the last release shipped.
    private func profile(_ old: String) throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let profile = Profile(
            name: "Work",
            monitorSets: [MonitorSet(monitors: ["A:100x100"])],
            spaceModes: [:],
            settings: TilingSettings()
        )
        return try envelope(encoder.encode(profile), format: 35, old)
    }

    private func migrated(gui old: String) throws -> [String: Any] {
        try migrated(gui(old))
    }

    private func migrated(profile old: String) throws -> [String: Any] {
        try migrated(profile(old))
    }

    private func migrated(_ root: [String: Any]) throws -> [String: Any] {
        let data = try #require(
            ConfigMigration.migrated(
                JSONSerialization.data(withJSONObject: root)
            )
        )
        return try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
    }

    private func map(_ object: [String: Any]?) throws -> GestureMap {
        let value = try #require(object?["gesture"])
        let data = try JSONSerialization.data(withJSONObject: value)
        return try JSONDecoder().decode(GestureMap.self, from: data)
    }

    @Test("gui.json folds every moved setting and drops the old keys")
    func guiFolds() throws {
        let root = try migrated(
            gui: #"""
                {"scroll_gesture": {"pan": "control+shift+option",
                   "space_step": "control+option+command",
                   "long_swipes": true},
                 "modifier_drag": {
                   "move": {"modifiers": "control+command", "start": "drag"},
                   "resize": {"modifiers": "", "start": "drag"}},
                 "trackpad_gesture": {
                   "tap3": null,
                   "swipe3": {"family": "swap",
                     "modifiers": "control+option"}}}
                """#
        )
        #expect(root["modifier_drag"] == nil)
        #expect(root["trackpad_gesture"] == nil)
        let scroll = try #require(root["scroll_gesture"] as? [String: Any])
        #expect(scroll["pan"] == nil)
        #expect(scroll["space_step"] == nil)
        #expect(scroll["long_swipes"] as? Bool == true)
        let gestures = try map(root)
        let pan: ScrollChord = [.control, .option, .shift]
        let seed: ScrollChord = [.control, .option]
        #expect(gestures[GestureKey(.swipe2, pan)] == .bound(.family(.focus)))
        #expect(gestures[GestureKey(.wheel, pan)] == .bound(.family(.walk)))
        #expect(gestures[GestureKey(.wheelX, pan)] == .bound(.family(.walk)))
        #expect(gestures[GestureKey(.swipe2, seed)] == .unbound)
        #expect(gestures[GestureKey(.wheel, seed)] == .unbound)
        #expect(gestures[GestureKey(.wheelX, seed)] == .unbound)
        // The Space step and the move stayed on their seeds.
        #expect(
            gestures[GestureKey(.wheel, [.control, .option, .command])]
                == nil
        )
        #expect(gestures[GestureKey(.drag, [.control, .command])] == nil)
        // The resize was off: its seed is tombstoned, no row added.
        #expect(gestures[GestureKey(.drag, seed)] == .unbound)
        #expect(gestures[GestureKey(.tap3)] == .unbound)
        #expect(
            gestures[GestureKey(.swipe3, seed)] == .bound(.family(.swap))
        )
        let resolved = GestureSeeds.resolved(base: gestures, profile: nil)
        #expect(resolved[GestureKey(.swipe2, seed)] == nil)
        #expect(
            resolved[GestureKey(.drag, [.control, .command])]
                == .grab(.move)
        )
    }

    @Test("a profile's pan tombstones the seed and adds its own rows")
    func profileFolds() throws {
        let root = try migrated(
            profile: #"""
                {"scroll_gesture": {"pan": "command+option"}}
                """#
        )
        let gestures = try map(root)
        let own: ScrollChord = [.command, .option]
        #expect(gestures[GestureKey(.swipe2, own)] == .bound(.family(.focus)))
        #expect(
            gestures[GestureKey(.swipe2, [.control, .option])] == .unbound
        )
        #expect(root["scroll_gesture"] as? [String: Any] != nil)
    }

    @Test("a bundle folds its config and every profile")
    func bundleFolds() throws {
        let root = try migrated([
            "format": 44,
            "writtenBy": "test",
            "config": try gui(
                #"""
                {"modifier_drag": {
                   "move": {"modifiers": "option+command", "start": "hover"}}}
                """#
            ),
            "profiles": [
                try profile(#"{"scroll_gesture": {"space_step": ""}}"#)
            ],
        ])
        let config = try #require(root["config"] as? [String: Any])
        let gestures = try map(config)
        // A key-started move becomes a hover row; the drag seed ends.
        #expect(
            gestures[GestureKey(.hoverMove, [.option, .command])]
                == .bound(.grab(.move))
        )
        #expect(gestures[GestureKey(.drag, [.option, .command])] == nil)
        #expect(gestures[GestureKey(.drag, [.control, .command])] == .unbound)
        let profiles = try #require(root["profiles"] as? [[String: Any]])
        let step: ScrollChord = [.control, .option, .command]
        let own = try map(profiles.first)
        #expect(own[GestureKey(.wheel, step)] == .unbound)
        #expect(own[GestureKey(.wheelX, step)] == .unbound)
        #expect(own[GestureKey(.swipe2, step)] == .unbound)
    }

    @Test("a move onto the resize seed keeps its row")
    func moveOntoResizeSeed() throws {
        let root = try migrated(
            gui: #"""
                {"modifier_drag": {
                   "move": {"modifiers": "control+option", "start": "drag"},
                   "resize": {"modifiers": "shift+command", "start": "hover"}}}
                """#
        )
        let gestures = try map(root)
        #expect(
            gestures[GestureKey(.drag, [.control, .option])]
                == .bound(.grab(.move))
        )
        #expect(
            gestures[GestureKey(.hoverMove, [.shift, .command])]
                == .bound(.grab(.resize))
        )
        #expect(gestures[GestureKey(.drag, [.control, .command])] == .unbound)
    }

    @Test("where the pan and the Space step share a chord, the pan wins")
    func panWinsASharedChord() throws {
        let root = try migrated(
            gui: #"""
                {"scroll_gesture": {"pan": "command+option",
                   "space_step": "command+option"}}
                """#
        )
        let gestures = try map(root)
        let keys: ScrollChord = [.command, .option]
        #expect(gestures[GestureKey(.swipe2, keys)] == .bound(.family(.focus)))
        #expect(gestures[GestureKey(.wheel, keys)] == .bound(.family(.walk)))
        let step: ScrollChord = [.control, .option, .command]
        #expect(gestures[GestureKey(.wheel, step)] == .unbound)
    }

    @Test("swapped chords keep both gestures, neither tombstoning")
    func swappedChordsKeepBoth() throws {
        let root = try migrated(
            gui: #"""
                {"scroll_gesture": {"pan": "control+option+command",
                   "space_step": "control+option"}}
                """#
        )
        let gestures = try map(root)
        let pan: ScrollChord = [.control, .option, .command]
        let step: ScrollChord = [.control, .option]
        for input: GestureInput in [.wheel, .wheelX] {
            let walk = gestures[GestureKey(input, pan)]
            let space = gestures[GestureKey(input, step)]
            #expect(walk == .bound(.family(.walk)))
            #expect(space == .bound(.family(.space)))
        }
        #expect(gestures[GestureKey(.swipe2, pan)] == .bound(.family(.focus)))
    }

    @Test("a pan on the step's seed keeps it when both share it")
    func sharedStepSeedKeepsThePan() throws {
        let root = try migrated(
            gui: #"""
                {"scroll_gesture": {"pan": "control+option+command",
                   "space_step": "control+option+command"}}
                """#
        )
        let gestures = try map(root)
        let seed: ScrollChord = [.control, .option, .command]
        #expect(gestures[GestureKey(.swipe2, seed)] == .bound(.family(.focus)))
        #expect(gestures[GestureKey(.wheel, seed)] == .bound(.family(.walk)))
    }

    @Test("a profile's chord on the seed is written as its own rows")
    func profileSeedChordIsExplicit() throws {
        let root = try migrated(
            profile: #"""
                {"scroll_gesture": {"pan": "control+option"}}
                """#
        )
        let gestures = try map(root)
        let seed: ScrollChord = [.control, .option]
        #expect(gestures[GestureKey(.swipe2, seed)] == .bound(.family(.focus)))
        #expect(gestures[GestureKey(.wheel, seed)] == .bound(.family(.walk)))
    }

    @Test("an alias spelling folds to the one key it names")
    func aliasSpellingIsCanonical() throws {
        let root = try migrated(
            gui: #"""
                {"scroll_gesture": {"pan": "opt+ctrl"},
                 "trackpad_gesture": {
                   "swipe3": {"family": "swap", "modifiers": "cmd+ctrl"}}}
                """#
        )
        let gestures = try map(root)
        let seed: ScrollChord = [.control, .option]
        #expect(gestures[GestureKey(.swipe2, seed)] == nil)
        #expect(
            gestures[GestureKey(.swipe3, [.control, .command])]
                == .bound(.family(.swap))
        )
    }

    @Test("a crossed file has nothing left to fold")
    func idempotent() throws {
        let once = try JSONSerialization.data(
            withJSONObject: try migrated(
                gui: #"{"scroll_gesture": {"pan": "control+shift"}}"#
            )
        )
        #expect(ConfigMigration.migratingGesturesIntoBindings(once) == nil)
    }
}
