import Foundation
import Testing

@testable import KiwiDeskCore

/// The scroll gestures' stored settings (#1656): a global base in
/// `gui.json`, a sparse per-profile override, their resolve, and
/// the chord's wire spelling.
@Suite("Scroll gesture config")
struct ScrollGestureConfigTests {
    private func json<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return String(decoding: try encoder.encode(value), as: UTF8.self)
    }

    private func decode<T: Decodable>(
        _ type: T.Type,
        _ text: String
    ) throws -> T {
        try JSONDecoder().decode(type, from: Data(text.utf8))
    }

    @Test("a chord spells like a keybinding's modifiers")
    func spelling() throws {
        let all: ScrollChord = [.command, .shift, .option, .control]
        #expect(all.spelling == "control+option+shift+command")
        #expect(ScrollChord([]).spelling == "")
        #expect(ScrollChord(spelling: "cmd+alt") == [.command, .option])
        #expect(ScrollChord(spelling: "") == [])
        #expect(ScrollChord(spelling: "control+hyper") == nil)
        #expect(ScrollChord(spelling: "ctrl+control") == nil)
        #expect(
            try json(ScrollChord([.control, .option])) == "\"control+option\""
        )
        #expect(throws: DecodingError.self) {
            try decode(ScrollChord.self, "\"control+fn\"")
        }
    }

    @Test("the base encodes every key and round-trips")
    func baseShape() throws {
        let text = try json(ScrollGestureBase.defaults)
        #expect(
            text == "{\"long_swipes\":false,"
                + "\"natural_scrolling\":"
                + "{\"mouse\":\"system\",\"trackpad\":\"system\"},"
                + "\"step_distance\":60}"
        )
        #expect(
            try decode(ScrollGestureBase.self, text) == .defaults
        )
    }

    @Test("a profile carries its override, and none by default")
    func profileCarriesTheOverride() throws {
        var profile = Profile(
            name: "P",
            monitorSets: [MonitorSet(monitors: ["m"])],
            spaceModes: [:],
            settings: TilingSettings()
        )
        #expect(
            try decode(Profile.self, try json(profile)).scrollGesture == nil
        )
        profile.scrollGesture = ScrollGestureOverride(naturalTrackpad: .off)
        #expect(
            try json(profile.scrollGesture!)
                == "{\"natural_scrolling\":{\"trackpad\":false}}"
        )
        let back = try decode(Profile.self, try json(profile))
        #expect(back.scrollGesture == profile.scrollGesture)
    }
}
