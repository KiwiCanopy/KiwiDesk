import Foundation
import Testing

@testable import KiwiDeskCore

/// `modifier_drag`'s fold into the drag rows (#3199, #3444), split
/// from `GestureMigrationTests` at the file ceiling: a pair on the
/// old defaults takes the map's drag seeds, and a pair that left
/// them is kept whole over tombstoned seeds.
@Suite("Gesture binding migration: drags")
struct GestureMigrationDragTests {
    private func migrated(gui old: String) throws -> [String: Any] {
        var root = try #require(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(GuiConfig())
            ) as? [String: Any]
        )
        root["format"] = 20
        let extra = try #require(
            JSONSerialization.jsonObject(with: Data(old.utf8))
                as? [String: Any]
        )
        root.merge(extra) { _, new in new }
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
        #expect(
            gestures[GestureKey(.drag, [.control, .option, .shift])]
                == .unbound
        )
        #expect(gestures[GestureKey(.drag, [.control, .command])] == nil)
    }

    /// No crossing pins the old drags (#3444 ▸ Ruling): a pair on
    /// the old defaults takes the map's seeds.
    @Test("a pair on the old defaults takes the new drag seeds")
    func defaultPairTakesTheSeeds() throws {
        let root = try migrated(
            gui: #"""
                {"modifier_drag": {
                   "move": {"modifiers": "control+command", "start": "drag"},
                   "resize": {"modifiers": "control+option",
                     "start": "drag"}}}
                """#
        )
        #expect(root["modifier_drag"] == nil)
        let stored = root["gesture"] as? [String: Any] ?? [:]
        #expect(!stored.keys.contains { $0.hasPrefix("drag") })
        let gestures = stored.isEmpty ? GestureMap() : try map(root)
        let resolved = GestureSeeds.resolved(
            base: gestures,
            profile: nil,
            shortcutBase: .standard
        )
        #expect(
            resolved[GestureKey(.drag, [.control, .option])] == .grab(.move)
        )
        #expect(resolved[GestureKey(.drag, [.control, .command])] == nil)
    }

    @Test("a resize on the move's chord stays the move's")
    func sharedDragChordIsTheMoves() throws {
        let root = try migrated(
            gui: #"""
                {"modifier_drag": {
                   "resize": {"modifiers": "control+command",
                     "start": "drag"}}}
                """#
        )
        let gestures = try map(root)
        #expect(
            gestures[GestureKey(.drag, [.control, .command])]
                == .bound(.grab(.move))
        )
        #expect(gestures[GestureKey(.drag, [.control, .option])] == .unbound)
        let resolved = GestureSeeds.resolved(
            base: gestures,
            profile: nil,
            shortcutBase: .standard
        )
        #expect(
            resolved[GestureKey(.drag, [.control, .command])] == .grab(.move)
        )
    }
}
