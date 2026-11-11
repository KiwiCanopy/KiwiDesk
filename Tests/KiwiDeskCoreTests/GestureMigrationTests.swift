import Foundation
import Testing

@testable import KiwiDeskCore

/// The fold of the fixed gesture settings into the binding list
/// (#3199, `migratingGesturesIntoBindings`), through
/// `ConfigMigration.migrated` from the formats the last release
/// shipped. The old types are gone with the step, so the fixtures
/// spell their wire shape by hand, as each old encoder wrote it.
@Suite("Gesture binding migration")
struct GestureMigrationTests {
    private func migrated(_ json: String) throws -> [String: Any] {
        let data = try #require(
            ConfigMigration.migrated(Data(json.utf8))
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
            #"""
            {"format": 20, "spaces": [], "layers": [],
             "scroll_gesture": {"pan": "control+shift+option",
               "space_step": "control+option+command",
               "long_swipes": true},
             "modifier_drag": {
               "move": {"modifiers": "control+command", "start": "drag"},
               "resize": {"modifiers": "", "start": "drag"}},
             "trackpad_gesture": {
               "tap3": null,
               "swipe3": {"family": "swap", "modifiers": "control+option"}}}
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
                == .grab(GestureGrab(.move))
        )
    }

    @Test("a profile's pan tombstones the seed and adds its own rows")
    func profileFolds() throws {
        let root = try migrated(
            #"""
            {"format": 35, "name": "Work", "monitorSets": [],
             "spaceModes": {}, "settings": {},
             "scroll_gesture": {"pan": "command+option"}}
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
        let root = try migrated(
            #"""
            {"format": 44, "writtenBy": "test",
             "config": {"format": 20, "spaces": [], "layers": [],
               "modifier_drag": {
                 "move": {"modifiers": "option+command", "start": "hover"}}},
             "profiles": [{"format": 35, "name": "A", "monitorSets": [],
               "spaceModes": {}, "settings": {},
               "scroll_gesture": {"space_step": ""}}]}
            """#
        )
        let config = try #require(root["config"] as? [String: Any])
        let gestures = try map(config)
        // A key-started move becomes a hover row; the drag seed ends.
        #expect(
            gestures[GestureKey(.hoverMove, [.option, .command])]
                == .bound(.grab(GestureGrab(.move)))
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
            #"""
            {"format": 20, "spaces": [], "layers": [],
             "modifier_drag": {
               "move": {"modifiers": "control+option", "start": "drag"},
               "resize": {"modifiers": "shift+command", "start": "hover"}}}
            """#
        )
        let gestures = try map(root)
        #expect(
            gestures[GestureKey(.drag, [.control, .option])]
                == .bound(.grab(GestureGrab(.move)))
        )
        #expect(
            gestures[GestureKey(.hoverMove, [.shift, .command])]
                == .bound(.grab(GestureGrab(.resize)))
        )
        #expect(gestures[GestureKey(.drag, [.control, .command])] == .unbound)
    }

    @Test("where the pan and the Space step share a chord, the pan wins")
    func panWinsASharedChord() throws {
        let root = try migrated(
            #"""
            {"format": 20, "spaces": [], "layers": [],
             "scroll_gesture": {"pan": "command+option",
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

    @Test("a crossed file has nothing left to fold")
    func idempotent() throws {
        let once = try JSONSerialization.data(
            withJSONObject: try migrated(
                #"{"format": 20, "scroll_gesture": {"pan": "control+shift"}}"#
            )
        )
        #expect(ConfigMigration.migratingGesturesIntoBindings(once) == nil)
    }
}
