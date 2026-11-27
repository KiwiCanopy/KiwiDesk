import Foundation
import Testing

@testable import KiwiDeskCore

/// The bars' and the pocket's per-screen maps cross from fingerprint
/// keys onto the profile's screen numbers (#3647 ▸ lane 3c), at every
/// reader of the shape: a profile file and a backup's `profiles[]`,
/// each through `ConfigMigration.migrated` from the format the last
/// release shipped. Fixtures are the encoder's output with the old
/// keys put back and the format re-stamped. A key that is no number
/// refuses the file once it is current, and a look never carries
/// these paths.
@Suite("Numbered bar map migration (#3647)")
struct NumberedBarMapMigrationTests {
    private let home = ["A:2000x1000", "B:1000x1000"]
    private let cowork = ["C:1000x500", "A:2000x1000"]

    private func encoded(_ value: some Encodable) throws -> [String: Any] {
        try #require(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(value)
            ) as? [String: Any]
        )
    }

    private func data(_ root: [String: Any]) throws -> Data {
        try JSONSerialization.data(
            withJSONObject: root,
            options: [.prettyPrinted, .sortedKeys]
        )
    }

    /// Writes `map` at `path` under the owner's `settings`.
    private func put(
        _ owner: inout [String: Any],
        _ path: [String],
        _ map: [String: Any]
    ) {
        var settings = owner["settings"] as? [String: Any] ?? [:]
        func write(_ node: inout [String: Any], _ rest: ArraySlice<String>) {
            guard let head = rest.first else { return }
            if rest.count == 1 {
                node[head] = map
                return
            }
            var child = node[head] as? [String: Any] ?? [:]
            write(&child, rest.dropFirst())
            node[head] = child
        }
        write(&settings, path[...])
        owner["settings"] = settings
    }

    private var profile: Profile {
        Profile(
            name: "Work",
            monitorSets: [
                MonitorSet(monitors: home),
                MonitorSet(monitors: cowork),
            ],
            spaceModes: [:],
            settings: TilingSettings()
        )
    }

    @Test("every bar map crosses onto numbers, the first set winning")
    func profileCrosses() throws {
        var root = try encoded(profile)
        let edges: [String: Any] = [
            "A:2000x1000": "left",
            "B:1000x1000#2": "top",
            "C:1000x500": "right",
            "Gone:1x1": "bottom",
        ]
        for path in ConfigMigration.numberedBarMapPaths {
            let isEdge = path.last?.contains("edge") == true
            put(
                &root,
                path,
                isEdge
                    ? edges
                    : ["B:1000x1000": "hidden", "Gone:1x1": "auto"]
            )
        }
        root["format"] = 44
        let out = try #require(ConfigMigration.migrated(data(root)))
        let read = try JSONDecoder().decode(Profile.self, from: out)
        let s = read.settings
        // A is Screen 1 in the first set; C's 1 in the second loses,
        // and a fingerprint no set holds is dropped.
        let numbered: [String: AppBarEdge] = ["1": .left, "2#2": .top]
        #expect(s.spaceBarStyle.edgeOverride == numbered)
        #expect(s.appBarStyle.edgeOverride == numbered)
        #expect(s.kiwishelf.pocketEdgeOverride == numbered)
        let shown: [String: ShelfVisibility] = ["2": .hidden]
        #expect(s.spaceBarStyle.visibilityOverride == shown)
        #expect(s.monocle.appBar.visibilityOverride == shown)
        #expect(s.scrolling.appBar.visibilityOverride == shown)
    }

    /// Each map alone opens the step: maps are written sparse, so a
    /// profile may carry one and no other.
    @Test("each map alone crosses")
    func eachPathAloneCrosses() throws {
        for path in ConfigMigration.numberedBarMapPaths {
            var root = try encoded(profile)
            let isEdge = path.last?.contains("edge") == true
            put(&root, path, ["B:1000x1000": isEdge ? "left" : "hidden"])
            root["format"] = 44
            let out = try #require(
                ConfigMigration.migrated(data(root)),
                "\(path)"
            )
            let s = try JSONDecoder().decode(Profile.self, from: out).settings
            let keys: [String] =
                switch path.joined(separator: ".") {
                case "space_bar.edge_override":
                    Array(s.spaceBarStyle.edgeOverride.keys)
                case "app_bar.edge_override":
                    Array(s.appBarStyle.edgeOverride.keys)
                case "kiwishelf.pocket_edge_override":
                    Array(s.kiwishelf.pocketEdgeOverride.keys)
                case "space_bar.visibility_override":
                    Array(s.spaceBarStyle.visibilityOverride.keys)
                case "layout.monocle.app_bar.visibility_override":
                    Array(s.monocle.appBar.visibilityOverride.keys)
                default:
                    Array(s.scrolling.appBar.visibilityOverride.keys)
                }
            #expect(keys == ["2"], "\(path)")
        }
    }

    @Test("a backup's profiles cross")
    func bundleCrosses() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var bundle = try #require(
            JSONSerialization.jsonObject(
                with: encoder.encode(
                    SetupBundle(
                        writtenBy: "test",
                        config: GuiConfig(),
                        profiles: [profile],
                        palettes: []
                    )
                )
            ) as? [String: Any]
        )
        var profiles = try #require(bundle["profiles"] as? [[String: Any]])
        put(
            &profiles[0],
            ["space_bar", "edge_override"],
            ["B:1000x1000": "left"]
        )
        bundle["profiles"] = profiles
        bundle["format"] = 56
        let out = try #require(ConfigMigration.migrated(data(bundle)))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let read = try decoder.decode(SetupBundle.self, from: out)
        #expect(
            read.profiles.first?.settings.spaceBarStyle.edgeOverride
                == ["2": .left]
        )
    }

    @Test("twins take the lower number")
    func twinsTakeTheLower() {
        let twin = "T:1000x1000"
        let out = ConfigMigration.numbered(
            [twin: "left"],
            sets: [["B:1000x1000", twin, twin]]
        )
        #expect(out.keys.sorted() == ["2"])
    }

    @Test("a current file is never crossed again")
    func currentFileStandsDown() throws {
        var root = try encoded(profile)
        put(&root, ["space_bar", "edge_override"], ["1": "left"])
        root["format"] = ConfigMigration.numberedBarMapsProfileFormat
        #expect(
            ConfigMigration.migratingBarMapsOntoNumbers(try data(root))
                == nil
        )
    }

    @Test("a fingerprint key refuses a current file")
    func fingerprintKeyRefuses() throws {
        func settings(_ path: [String], key: String) throws -> Data {
            var wrapper: [String: Any] = [
                "settings": try encoded(TilingSettings())
            ]
            let value = path.last?.contains("edge") == true ? "left" : "auto"
            put(&wrapper, path, [key: value])
            return try data(
                try #require(wrapper["settings"] as? [String: Any])
            )
        }
        for path in ConfigMigration.numberedBarMapPaths {
            // The control: the same root with a number decodes.
            #expect(throws: Never.self, "\(path)") {
                try JSONDecoder().decode(
                    TilingSettings.self,
                    from: settings(path, key: "1")
                )
            }
            #expect(throws: DecodingError.self, "\(path)") {
                try JSONDecoder().decode(
                    TilingSettings.self,
                    from: settings(path, key: "A:2000x1000")
                )
            }
        }
    }

    @Test("a look never carries a per-screen path")
    func lookCarriesNone() {
        var settings = TilingSettings()
        settings.spaceBarStyle.edgeOverride = ["1": .left]
        settings.appBarStyle.edgeOverride = ["1": .top]
        settings.kiwishelf.pocketEdgeOverride = ["1": .right]
        settings.spaceBarStyle.visibilityOverride = ["1": .hidden]
        settings.monocle.appBar.visibilityOverride = ["1": .hidden]
        settings.scrolling.appBar.visibilityOverride = ["1": .hidden]
        let body = LookBody(of: settings)
        #expect(!body.style.isEmpty)
        for path in ConfigMigration.numberedBarMapPaths {
            let joined = path.joined(separator: ".")
            #expect(body.style[joined] == nil, "\(joined)")
            #expect(
                !body.style.keys.contains { $0.hasPrefix(joined) },
                "\(joined)"
            )
        }
    }
}
