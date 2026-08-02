import Foundation
import Testing

@testable import KiwiDeskCore

/// Tests pinning `Profile.layers` — nil→absent sparse encoding
/// (O3) and round-trip correctness (AGENTS.md §5).
/// Parity with the `KeyLayerOverride` vocabulary tests lives in
/// `KeyLayerOverrideTests`; these focus on the Profile wrapper.
@Suite("Profile.layers — sparse encoding and round-trip (#55)")
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
        layers: KeyLayerOverride? = nil
    ) -> Profile {
        Profile(
            name: "test",
            monitorSets: [
                MonitorSet(monitors: ["A:1x1"])
            ],
            spaceModes: [:],
            settings: TilingSettings(),
            savedAt: Date(timeIntervalSince1970: 1_780_000_000),
            layers: layers
        )
    }

    // MARK: - Sparse nil encoding (O3)

    @Test("nil layers: key is ABSENT from JSON (not null)")
    func nilModesKeyAbsent() throws {
        let profile = baseProfile(layers: nil)
        let data = try encoder.encode(profile)
        let json = try #require(
            String(data: data, encoding: .utf8)
        )
        // The key must be completely absent — never "layers":null.
        #expect(!json.contains("\"layers\""))
    }

    @Test("nil layers decodes from JSON without layers key")
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
        #expect(profile.layers == nil)
    }

    // MARK: - Round-trip with layers present

    @Test("Present layers round-trip: encode→decode equals original")
    func presentModesRoundTrip() throws {
        let override = KeyLayerOverride(
            layers: [
                KeyLayer(
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
        let profile = baseProfile(layers: override)
        let data = try encoder.encode(profile)
        let back = try decoder.decode(Profile.self, from: data)
        #expect(back.layers == override)
    }

    // MARK: - JSON shape pin (SettingsCodingTests vocabulary rule)

    @Test("layers key encodes as a bare JSON array (not object)")
    func modesKeyIsBareArray() throws {
        let override = KeyLayerOverride(
            layers: [
                KeyLayer(name: "default", bindings: [])
            ]
        )
        let profile = baseProfile(layers: override)
        let data = try encoder.encode(profile)
        let json = try #require(
            String(data: data, encoding: .utf8)
        )
        // Must be "layers":[...] not "layers":{...}
        #expect(json.contains("\"layers\":["))
        #expect(!json.contains("\"layers\":{"))
    }

    @Test("layers array shape matches GuiConfig.layers vocabulary")
    func modesArrayMatchesGuiConfig() throws {
        // Profile "layers" must decode from the same JSON shape
        // that GuiConfig.layers encodes — one vocabulary (#5).
        let guiModes: [KeyLayer] = [
            KeyLayer(
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
        config.layers = guiModes
        let guiEncoder = JSONEncoder()
        let guiData = try guiEncoder.encode(config)
        let guiDecoded = try JSONDecoder().decode(
            GuiConfig.self,
            from: guiData
        )
        // Same layers encoded via GuiConfig must survive as
        // KeyLayerOverride when wrapped in a bare array.
        let asOverride = KeyLayerOverride(layers: guiDecoded.layers)
        let overData = try JSONEncoder().encode(asOverride)
        let overBack = try JSONDecoder().decode(
            KeyLayerOverride.self,
            from: overData
        )
        #expect(overBack.layers == guiDecoded.layers)
    }
}
