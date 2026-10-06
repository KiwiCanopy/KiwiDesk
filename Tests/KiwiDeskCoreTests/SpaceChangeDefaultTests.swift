import Foundation
import Testing

@testable import KiwiDeskCore

/// **A Space switch plays the plate slide by default, and a stored
/// file keeps what it says** (#1931). The flip owes no #1369
/// crossing only because the encoder writes the `animations` group
/// whole, so every file KiwiDesk wrote carries its own
/// `on_space_change` (design-decisions ▸ #1359's thickness ruling).
/// The encoder clause is that premise: a sparse encoder would make
/// absence a stored value, and the flip would then owe a step.
@Suite("Space switch animation default (#1931)")
struct SpaceChangeDefaultTests {
    @Test("a new setup and an absent leaf animate the switch")
    func newDefaultIsOn() throws {
        #expect(TilingSettings().animations.onSpaceChange)
        let empty = try JSONDecoder().decode(
            AnimationSettings.self,
            from: Data("{}".utf8)
        )
        #expect(empty.onSpaceChange)
    }

    @Test("the encoder writes the leaf at either value")
    func encoderWritesTheLeaf() throws {
        for value in [false, true] {
            var settings = TilingSettings()
            settings.animations.onSpaceChange = value
            let root = try #require(
                JSONSerialization.jsonObject(
                    with: JSONEncoder().encode(settings)
                ) as? [String: Any]
            )
            let animations = try #require(
                root["animations"] as? [String: Any]
            )
            #expect(animations["on_space_change"] as? Bool == value)
        }
    }

    @Test("a stored off survives the round trip")
    func storedOffStaysOff() throws {
        var settings = TilingSettings()
        settings.animations.onSpaceChange = false
        let decoded = try JSONDecoder().decode(
            TilingSettings.self,
            from: JSONEncoder().encode(settings)
        )
        #expect(!decoded.animations.onSpaceChange)
    }
}
