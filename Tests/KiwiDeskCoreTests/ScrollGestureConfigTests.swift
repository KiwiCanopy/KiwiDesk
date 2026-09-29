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
                + "\"natural_scrolling\":{\"mouse\":true,\"trackpad\":true},"
                + "\"pan\":\"control+option\","
                + "\"space_step\":\"control+option+command\","
                + "\"step_distance\":60}"
        )
        #expect(
            try decode(ScrollGestureBase.self, text) == .defaults
        )
    }

    @Test("a key the file does not carry takes its default")
    func missingKeysDefault() throws {
        let base = try decode(ScrollGestureBase.self, "{\"pan\": \"\"}")
        #expect(base.pan == [])
        #expect(base.spaceStep == ScrollGestureBase.defaults.spaceStep)
        #expect(!base.longSwipes)
        #expect(base.stepDistance == 60)
    }

    @Test("an override writes only what it changes")
    func overrideIsSparse() throws {
        let over = ScrollGestureOverride(pan: [])
        #expect(try json(over) == "{\"pan\":\"\"}")
        #expect(try decode(ScrollGestureOverride.self, "{}").isEmpty)
    }

    @Test("resolve lays the override over the base, diff inverts it")
    func resolveAndDiff() {
        let base = ScrollGestureBase.defaults
        let over = ScrollGestureOverride(
            spaceStep: [.control, .shift],
            naturalMouse: false
        )
        let resolved = over.resolved(onto: base)
        #expect(resolved.pan == base.pan)
        #expect(resolved.spaceStep == [.control, .shift])
        #expect(!resolved.naturalMouse)
        #expect(resolved.naturalTrackpad)
        #expect(
            ScrollGestureOverride.diff(base: base, edited: resolved) == over
        )
        #expect(ScrollGestureOverride.diff(base: base, edited: base) == nil)
    }

    @Test("gui.json without the group decodes the defaults")
    func sidecarAbsentIsDefaults() throws {
        let config = try decode(GuiConfig.self, "{\"format\": 4}")
        #expect(config.scrollGesture == .defaults)
        var edited = config
        edited.scrollGesture.pan = [.command, .shift]
        let back = try decode(GuiConfig.self, try json(edited))
        #expect(back.scrollGesture.pan == [.command, .shift])
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
        profile.scrollGesture = ScrollGestureOverride(naturalTrackpad: false)
        #expect(
            try json(profile.scrollGesture!)
                == "{\"natural_scrolling\":{\"trackpad\":false}}"
        )
        let back = try decode(Profile.self, try json(profile))
        #expect(back.scrollGesture == profile.scrollGesture)
    }
}
