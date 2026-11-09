import Foundation
import Testing

@testable import KiwiDeskCore

/// The modifier drags' stored shape and refusals (#2447): on by
/// default with the button held, additive key by key, and the
/// verbs and a hand-edited file refused alike.
@Suite("ModifierDragConfig")
struct ModifierDragConfigTests {
    private func decode(_ json: String) throws -> ModifierDragSettings {
        try JSONDecoder().decode(
            ModifierDragSettings.self,
            from: Data(json.utf8)
        )
    }

    @Test("the defaults are the ruling's: ⌃⌘ moves, ⌃⌥ resizes, drag")
    func defaults() {
        let d = ModifierDragSettings.defaults
        #expect(d.move == ModifierDragBinding(chord: [.control, .command]))
        #expect(d.resize == ModifierDragBinding(chord: [.control, .option]))
        #expect(d.move.start == .drag && d.resize.start == .drag)
        #expect(d.sanitized == d)
    }

    @Test("the wire round-trips and states every key")
    func roundTrip() throws {
        var settings = ModifierDragSettings.defaults
        settings.resize = ModifierDragBinding(
            chord: [.option, .shift],
            start: .hover
        )
        let data = try JSONEncoder().encode(settings)
        #expect(
            try JSONDecoder().decode(ModifierDragSettings.self, from: data)
                == settings
        )
        let object = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        #expect(Set(object.keys) == ["move", "resize"])
        let move = try #require(object["move"] as? [String: Any])
        #expect(Set(move.keys) == ["modifiers", "start"])
    }

    @Test("a key a file leaves out keeps its default")
    func additive() throws {
        #expect(try decode("{}") == .defaults)
        let partial = try decode(#"{"resize": {"start": "hover"}}"#)
        #expect(partial.move == ModifierDragSettings.defaults.move)
        #expect(partial.resize.chord == [.control, .option])
        #expect(partial.resize.start == .hover)
        let off = try decode(#"{"move": {"modifiers": ""}}"#)
        #expect(off.move.isOff)
    }

    @Test("an unknown start is refused, never read leniently")
    func strict() {
        #expect(throws: (any Error).self) {
            try decode(#"{"move": {"start": "click"}}"#)
        }
    }

    @Test("gui.json carries the group, absence the defaults")
    func guiConfig() throws {
        var config = GuiConfig()
        config.modifierDrag.move.start = .hover
        let data = try JSONEncoder().encode(config)
        let back = try JSONDecoder().decode(GuiConfig.self, from: data)
        #expect(back.modifierDrag == config.modifierDrag)
        #expect(GuiConfig().modifierDrag == .defaults)
    }

    @Test("a lone modifier is kept; a shared chord is the move's")
    func sanitized() {
        var settings = ModifierDragSettings.defaults
        settings.move.chord = [.command]
        #expect(settings.sanitized.move.chord == [.command])
        settings = .defaults
        settings.resize.chord = settings.move.chord
        #expect(settings.sanitized.resize.isOff)
        #expect(settings.sanitized.move == settings.move)
    }

    @Test("the refusals the recorder and the verbs share")
    func refusals() {
        #expect(
            ModifierDragRefusal.of([], other: [.control], heldBy: .move) == nil
        )
        // One key is the user's choice (owner, 2026-11-08).
        #expect(
            ModifierDragRefusal.of([.option], other: [], heldBy: .move) == nil
        )
        #expect(
            ModifierDragRefusal.of(
                [.control, .command],
                other: [.control, .command],
                heldBy: .move
            ) == .otherAction(.move)
        )
    }
}
