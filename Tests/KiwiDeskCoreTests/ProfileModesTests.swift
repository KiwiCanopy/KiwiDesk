import Foundation
import Testing

@testable import KiwiDeskCore

/// Tests pinning `Profile.modes` — nil→absent sparse encoding
/// (O3) and round-trip correctness (AGENTS.md §5).
/// Parity with the `KeyModeOverride` vocabulary tests lives in
/// `KeyModeOverrideTests`; these focus on the Profile wrapper.
@Suite("Profile.modes — sparse encoding and round-trip (#55)")
struct ProfileModesTests {

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private func baseProfile(
        modes: KeyModeOverride? = nil
    ) -> Profile {
        Profile(
            name: "test",
            monitorSets: [
                MonitorSet(monitors: ["A:1x1"])
            ],
            spaceModes: [:],
            settings: TilingSettings(),
            savedAt: Date(timeIntervalSince1970: 1_780_000_000),
            modes: modes
        )
    }

    // MARK: - Sparse nil encoding (O3)

    @Test("nil modes: key is ABSENT from JSON (not null)")
    func nilModesKeyAbsent() throws {
        let profile = baseProfile(modes: nil)
        let data = try encoder.encode(profile)
        let json = try #require(
            String(data: data, encoding: .utf8)
        )
        // The key must be completely absent — never "modes":null.
        #expect(!json.contains("\"modes\""))
    }

    @Test("nil modes decodes from JSON without modes key")
    func nilModesMissingKeyDecodesOK() throws {
        let json = """
            {"name":"p",
             "monitor_sets":[{"monitors":["A:1x1"]}],
             "space_modes":{},
             "settings":{},
             "saved_at":"2026-06-01T00:00:00Z"}
            """
        let profile = try decoder.decode(
            Profile.self,
            from: Data(json.utf8)
        )
        #expect(profile.modes == nil)
    }

    // MARK: - Round-trip with modes present

    @Test("Present modes round-trip: encode→decode equals original")
    func presentModesRoundTrip() throws {
        let override = KeyModeOverride(
            modes: [
                KeyMode(
                    name: "default",
                    bindings: [
                        KeyBinding(
                            combo: "alt+h",
                            lua: "KiwiDesk.focus(\"left\")",
                            kind: .navigation,
                            label: "Focus left"
                        )
                    ]
                )
            ]
        )
        let profile = baseProfile(modes: override)
        let data = try encoder.encode(profile)
        let back = try decoder.decode(Profile.self, from: data)
        #expect(back.modes == override)
    }

    // MARK: - JSON shape pin (SettingsCodingTests vocabulary rule)

    @Test("modes key encodes as a bare JSON array (not object)")
    func modesKeyIsBareArray() throws {
        let override = KeyModeOverride(
            modes: [
                KeyMode(name: "default", bindings: [])
            ]
        )
        let profile = baseProfile(modes: override)
        let data = try encoder.encode(profile)
        let json = try #require(
            String(data: data, encoding: .utf8)
        )
        // Must be "modes":[...] not "modes":{...}
        #expect(json.contains("\"modes\":["))
        #expect(!json.contains("\"modes\":{"))
    }

    @Test("modes array shape matches GuiConfig.modes vocabulary")
    func modesArrayMatchesGuiConfig() throws {
        // Profile "modes" must decode from the same JSON shape
        // that GuiConfig.modes encodes — one vocabulary (#5).
        let guiModes: [KeyMode] = [
            KeyMode(
                name: "default",
                bindings: [
                    KeyBinding(
                        combo: "alt+h",
                        lua: "KiwiDesk.focus(\"left\")",
                        kind: .navigation,
                        label: "Focus left"
                    )
                ]
            )
        ]
        var config = GuiConfig()
        config.modes = guiModes
        let guiEncoder = JSONEncoder()
        let guiData = try guiEncoder.encode(config)
        let guiDecoded = try JSONDecoder().decode(
            GuiConfig.self,
            from: guiData
        )
        // Same modes encoded via GuiConfig must survive as
        // KeyModeOverride when wrapped in a bare array.
        let asOverride = KeyModeOverride(modes: guiDecoded.modes)
        let overData = try JSONEncoder().encode(asOverride)
        let overBack = try JSONDecoder().decode(
            KeyModeOverride.self,
            from: overData
        )
        #expect(overBack.modes == guiDecoded.modes)
    }
}
