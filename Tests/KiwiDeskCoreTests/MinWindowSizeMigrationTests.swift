import Foundation
import Testing

@testable import KiwiDeskCore

/// The minimum window size's crossing (#2237): one stored number
/// becomes one width × height per layout, so a file below the
/// floor keeps the floor it drew on every layout.
///
/// Every fixture is what the ENCODER writes, with the one leaf put
/// back to the shape the previous build wrote (a bare number) and
/// the stamp moved below the floor — never a hand-written file
/// (memory: migration fixtures from the encoder).
@Suite("Minimum window size migration (#2237)")
struct MinWindowSizeMigrationTests {
    private static let key = "min_window_size"

    private func tree(_ data: Data) throws -> [String: Any] {
        try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
    }

    private func data(_ tree: [String: Any]) throws -> Data {
        try JSONSerialization.data(
            withJSONObject: tree,
            options: [.prettyPrinted, .sortedKeys]
        )
    }

    private func encoded(_ value: some Encodable) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(value)
    }

    /// `settings` with the leaf as the previous build wrote it —
    /// `side`, or absent where nil.
    private func legacy(
        _ settings: [String: Any],
        side: Double?
    ) -> [String: Any] {
        var out = settings
        out[Self.key] = side
        return out
    }

    private func profileTree(side: Double?) throws -> [String: Any] {
        var settings = TilingSettings()
        settings.stack.masterRatio = 0.4
        let profile = Profile(
            name: "P",
            monitorSets: [MonitorSet(monitors: ["A:100x100"])],
            spaceModes: [:],
            settings: settings
        )
        var root = try tree(encoded(profile))
        root["format"] = Profile.currentFormat - 1
        let inner = try #require(root["settings"] as? [String: Any])
        root["settings"] = legacy(inner, side: side)
        return root
    }

    private func expectEveryLayout(
        _ sizes: MinWindowSizes,
        is side: CGFloat
    ) {
        for layout in MinWindowSizes.Layout.allCases {
            #expect(sizes[layout] == .square(side), "\(layout)")
        }
    }

    @Test("a profile's number becomes every layout's width and height")
    func profileNumberSplits() throws {
        let before = try data(profileTree(side: 420))
        let after = try #require(ConfigMigration.migrated(before))
        let profile = try JSONDecoder().decode(Profile.self, from: after)
        expectEveryLayout(profile.settings.minWindowSizes, is: 420)
        #expect(profile.settings.stack.masterRatio == 0.4)
        #expect(profile.format == Profile.currentFormat)
    }

    @Test("a bundle's inline profiles cross")
    func bundleCrosses() throws {
        let bundle = SetupBundle(
            writtenBy: "test",
            config: GuiConfig(),
            profiles: [
                Profile(
                    name: "P",
                    monitorSets: [MonitorSet(monitors: ["A:1x1"])],
                    spaceModes: [:],
                    settings: TilingSettings()
                )
            ],
            palettes: []
        )
        var root = try tree(encoded(bundle))
        root["format"] = SetupBundle.currentFormat - 1
        var profiles = try #require(
            root["profiles"] as? [[String: Any]]
        )
        let profileSettings = try #require(
            profiles[0]["settings"] as? [String: Any]
        )
        profiles[0]["settings"] = legacy(profileSettings, side: 350)
        root["profiles"] = profiles
        let after = try #require(
            ConfigMigration.migrated(try data(root))
        )
        let decoded = try JSONDecoder().decode(
            SetupBundle.self,
            from: after
        )
        expectEveryLayout(
            try #require(decoded.profiles.first).settings
                .minWindowSizes,
            is: 350
        )
    }

    @Test("the step leaves a per-layout value alone")
    func stepIsIdempotent() throws {
        var settings = TilingSettings()
        settings.minWindowSizes.grid = MinSize(width: 220, height: 160)
        let profile = Profile(
            name: "P",
            monitorSets: [MonitorSet(monitors: ["A:1x1"])],
            spaceModes: [:],
            settings: settings
        )
        let current = try encoded(profile)
        #expect(
            ConfigMigration.migratingMinWindowSizePerLayout(current)
                == nil
        )
    }

    /// Built as text, the encoder's own bytes with the one leaf
    /// put back, so a re-serialization would show: a fixture that
    /// passed through `JSONSerialization` already spells 0.4 long.
    @Test("the edit touches nothing but the leaf")
    func editIsSurgical() throws {
        var settings = TilingSettings()
        settings.stack.masterRatio = 0.4
        let profile = Profile(
            format: Profile.currentFormat - 1,
            name: "P",
            monitorSets: [MonitorSet(monitors: ["A:1x1"])],
            spaceModes: [:],
            settings: settings
        )
        let text = try #require(
            String(data: try encoded(profile), encoding: .utf8)
        )
        let object = try #require(
            text.range(
                of: "\"min_window_size\" : \\{[^}]*(\\}[^}]*){5}\\}"
                    + "[^}]*\\}",
                options: .regularExpression
            )
        )
        var legacy = text
        legacy.replaceSubrange(object, with: "\"min_window_size\" : 420")
        #expect(legacy.contains("\"min_window_size\" : 420"))
        let after = try #require(
            ConfigMigration.migratingMinWindowSizePerLayout(
                Data(legacy.utf8)
            )
        )
        let out = try #require(String(data: after, encoding: .utf8))
        #expect(out.contains("\"master_ratio\" : 0.4"))
        #expect(!out.contains("0.40000000000000002"))
        let decoded = try JSONDecoder().decode(Profile.self, from: after)
        expectEveryLayout(decoded.settings.minWindowSizes, is: 420)
    }

}
