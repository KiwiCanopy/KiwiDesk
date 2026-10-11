import Foundation
import Testing

@testable import KiwiDeskCore

/// **A Space switch names the Space by default, and a file written
/// at the current format keeps the style it says** (#2143). A file
/// from before crosses once (`SpaceChangeStyleMigrationTests`); the
/// encoder clause is that step's premise — `animations` is written
/// whole, so the style is always a stored value.
@Suite("Space switch style default (#2143)")
struct SpaceChangeDefaultTests {
    @Test("a new setup and an absent leaf show the Space")
    func newDefaultIsTheCue() throws {
        #expect(TilingSettings().animations.spaceChange == .cue)
        let empty = try JSONDecoder().decode(
            AnimationSettings.self,
            from: Data("{}".utf8)
        )
        #expect(empty.spaceChange == .cue)
    }

    @Test("every style is written and read back")
    func everyStyleRoundTrips() throws {
        for style in SpaceChangeStyle.allCases {
            var settings = TilingSettings()
            settings.animations.spaceChange = style
            let data = try JSONEncoder().encode(settings)
            let root = try #require(
                JSONSerialization.jsonObject(with: data) as? [String: Any]
            )
            let animations = try #require(
                root["animations"] as? [String: Any]
            )
            #expect(animations["space_change"] as? String == style.rawValue)
            let decoded = try JSONDecoder().decode(
                TilingSettings.self,
                from: data
            )
            #expect(decoded.animations.spaceChange == style)
        }
    }

    /// Strict: a word the picker does not offer fails the file.
    @Test("an unknown style fails the decode")
    func unknownStyleFails() {
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(
                AnimationSettings.self,
                from: Data(#"{"space_change":"fade"}"#.utf8)
            )
        }
    }
}
