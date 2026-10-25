import Foundation
import Testing

@testable import KiwiDeskCore

/// ⌃⌥P moves from pin to Pocket (#2446): a stored row still running
/// the seeded pin on its seeded chord — ⌃⌥P, or ✦P on the Hyper base
/// — runs Pocket, in `gui.json` and a profile's override alike; a
/// chord the user gave pin themselves stays. Fixtures come from the
/// encoder.
@Suite("Pocket chord migration (#2446)")
struct PocketChordMigrationTests {
    /// The formats before the step — spelled, so a change to the
    /// step's own constants cannot move the fixtures with them.
    private let guiBefore = 16
    private let profileBefore = 30
    private let pin = "KiwiDesk.toggle_display_sticky()"

    private func row(_ combo: String, _ lua: String) -> KeyBinding {
        KeyBinding(
            combo: combo,
            lua: lua,
            kind: .navigation,
            label: lua == pin ? "Toggle display sticky" : ""
        )
    }

    private func gui(_ rows: [KeyBinding], format: Int) throws -> Data {
        var config = GuiConfig()
        config.format = format
        config.layers = [
            KeyLayer(name: KeyLayer.defaultName, bindings: rows)
        ]
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(config)
    }

    private func rows(_ data: Data) throws -> [KeyBinding] {
        let config = try JSONDecoder().decode(GuiConfig.self, from: data)
        return try #require(config.layers.first).bindings
    }

    @Test("the seeded pin on ⌃⌥P runs Pocket")
    func seededChordMoves() throws {
        let data = try gui(
            [row("control+option+p", pin)],
            format: guiBefore
        )
        let out = try #require(ConfigMigration.migrated(data))
        let moved = try #require(try rows(out).first)
        #expect(moved.lua == "KiwiDesk.pocket()")
        #expect(moved.combo == "control+option+p")
        #expect(moved.label == "Pocket this window")
    }

    @Test("the seeded pin on ✦P runs Pocket")
    func hyperChordMoves() throws {
        let data = try gui([row("hyper+p", pin)], format: guiBefore)
        let out = try #require(ConfigMigration.migrated(data))
        #expect(try rows(out).first?.lua == "KiwiDesk.pocket()")
    }

    @Test("a chord the user gave pin stays pin")
    func ownChordStays() throws {
        let data = try gui(
            [row("control+option+x", pin)],
            format: guiBefore
        )
        let out = ConfigMigration.migrated(data) ?? data
        let kept = try #require(try rows(out).first)
        #expect(kept.lua == pin)
        #expect(kept.combo == "control+option+x")
    }

    @Test("a file at the step's format keeps a pin on ⌃⌥P")
    func standsDownAtItsFloor() throws {
        let data = try gui(
            [row("control+option+p", pin)],
            format: ConfigMigration.pocketChordGuiFormat
        )
        #expect(ConfigMigration.migratingPinChordOntoPocket(data) == nil)
    }

    @Test("a profile's override crosses too")
    func profileOverrideCrosses() throws {
        let profile = Profile(
            format: profileBefore,
            name: "Work",
            monitorSets: [MonitorSet(monitors: ["A:100x100"])],
            spaces: [SpaceID("1")],
            spaceModes: [:],
            settings: TilingSettings(),
            layers: KeyLayerOverride(
                layers: [
                    KeyLayer(
                        name: KeyLayer.defaultName,
                        bindings: [row("control+option+p", pin)]
                    )
                ]
            )
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let out = try #require(
            ConfigMigration.migrated(try encoder.encode(profile))
        )
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let migrated = try decoder.decode(Profile.self, from: out)
        let bindings = try #require(migrated.layers?.layers.first)
            .bindings
        #expect(bindings.first?.lua == "KiwiDesk.pocket()")
    }

    @Test("the rewrite is surgical: other bytes stay as written")
    func surgical() throws {
        let data = try gui(
            [
                row("control+option+p", pin),
                row("control+option+f", "KiwiDesk.toggle_floating()"),
            ],
            format: guiBefore
        )
        let text = try #require(String(data: data, encoding: .utf8))
        let edited = try #require(
            ConfigMigration.surgicallyPocketing(text)
        )
        let out = String(decoding: edited, as: UTF8.self)
        #expect(!out.contains(pin))
        #expect(out.contains("KiwiDesk.toggle_floating()"))
        #expect(out.contains("\"Pocket this window\""))
    }
}
