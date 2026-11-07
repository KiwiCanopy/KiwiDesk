import Foundation
import Testing

@testable import KiwiDeskCore

/// The app-wide pocket capacity crosses onto each profile's
/// `kiwishelf.pocket_visibility` (#2978 ruling 7): the value each
/// profile takes, the files on disk by adoption, and a bundle in one
/// step.
@Suite("Pocket visibility crossing (#2978)", .serialized)
@MainActor
struct PocketVisibilityCrossingTests {
    private func settings(
        space: ShelfVisibility,
        app: ShelfVisibility,
        pocket edge: AppBarEdge = .top
    ) -> TilingSettings {
        var settings = TilingSettings()
        settings.spaceBarStyle.setEdge(.top)
        settings.spaceBarStyle.visibility = space
        for mode in LayoutMode.allCases {
            settings.setAppBarVisibility(app, in: mode)
        }
        settings.kiwishelf.pocketEdge = edge
        return settings
    }

    private func crossed(
        _ capacity: String,
        _ settings: TilingSettings
    ) -> ShelfVisibility {
        ConfigMigration.crossedPocketVisibility(
            capacity: capacity,
            settings: settings
        )
    }

    @Test("one is Hidden; several follows bars that agree")
    func agreeingBars() {
        for show in ShelfVisibility.allCases {
            let both = settings(space: show, app: show)
            #expect(crossed("one", both) == .hidden)
            #expect(
                crossed("several", both) == (show == .hidden ? .auto : show)
            )
        }
    }

    @Test("mixed bars take Always where the whole mark rested")
    func mixedBars() {
        // The pocket alone on the bottom edge, the bars Always and
        // Auto on top: it rested whole.
        let whole = settings(space: .always, app: .auto, pocket: .bottom)
        #expect(whole.restedWholeBeforeVisibility(in: .bsp))
        #expect(crossed("several", whole) == .always)
        // On the bars' edge it was a section or the handle.
        let onBars = settings(space: .always, app: .auto, pocket: .top)
        #expect(!onBars.restedWholeBeforeVisibility(in: .bsp))
        #expect(crossed("several", onBars) == .auto)
    }

    @Test("a profile file gains the key and keeps every other byte")
    func insertIsSurgical() throws {
        let text = #"""
            {"format":33,"settings":{"kiwishelf":{"pocket_edge":"top"},\#
            "space_bar":{"visibility":"auto"}}}
            """#
        let data = try #require(
            ConfigMigration.withPocketVisibility(.auto, in: Data(text.utf8))
        )
        let out = try #require(String(data: data, encoding: .utf8))
        #expect(
            out
                == text.replacingOccurrences(
                    of: #""kiwishelf":{"#,
                    with: #""kiwishelf":{"pocket_visibility":"auto","#
                )
        )
        let empty = #"{"settings":{"kiwishelf":{}}}"#
        let filled = try #require(
            ConfigMigration.withPocketVisibility(
                .hidden,
                in: Data(empty.utf8)
            )
        )
        let stamped =
            #"{"settings":{"kiwishelf":{"pocket_visibility":"hidden"}}}"#
        #expect(String(data: filled, encoding: .utf8) == stamped)
    }

    @Test("a bundle crosses its config's capacity into its profiles")
    func bundleStep() throws {
        var stated = TilingSettings()
        stated.kiwishelf.pocketVisibility = .always
        func object(_ settings: TilingSettings) throws -> Any {
            try JSONSerialization.jsonObject(
                with: JSONEncoder().encode(settings)
            )
        }
        var hidden = try #require(
            try object(settings(space: .hidden, app: .hidden))
                as? [String: Any]
        )
        var shelf = try #require(hidden["kiwishelf"] as? [String: Any])
        shelf["pocket_visibility"] = nil
        hidden["kiwishelf"] = shelf
        let root: [String: Any] = [
            "format": 42,
            "writtenBy": "test",
            "config": ["pocket": ["capacity": "several"]],
            "profiles": [
                ["settings": hidden],
                ["settings": try object(stated)],
            ],
        ]
        let data = try JSONSerialization.data(withJSONObject: root)
        let out = try #require(
            ConfigMigration.migratingPocketCapacityOntoShelf(data)
        )
        let crossed = try #require(
            JSONSerialization.jsonObject(with: out) as? [String: Any]
        )
        let config = try #require(crossed["config"] as? [String: Any])
        #expect(config["pocket"] == nil)
        let profiles = try #require(
            crossed["profiles"] as? [[String: Any]]
        )
        let values = profiles.map {
            (($0["settings"] as? [String: Any])?["kiwishelf"]
                as? [String: Any])?["pocket_visibility"] as? String
        }
        #expect(values == ["auto", "always"])
    }

    private func makeGuiCore(capacity: String) throws -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-pocket-\(UUID().uuidString)")
        )
        try core.guiConfigStore.save(GuiConfig())
        let url = core.guiConfigStore.url
        var root = try #require(
            JSONSerialization.jsonObject(with: Data(contentsOf: url))
                as? [String: Any]
        )
        root["pocket"] = ["capacity": capacity]
        try JSONSerialization.data(withJSONObject: root).write(to: url)
        return core
    }

    private func retired(_ core: KiwiCore) -> String? {
        (try? Data(contentsOf: core.guiConfigStore.url)).flatMap {
            ConfigMigration.retiredPocketCapacity(in: $0)
        }
    }

    /// Saves `name` as a file written before the pocket had a Show.
    private func saveLegacy(
        _ name: String,
        _ settings: TilingSettings,
        in core: KiwiCore
    ) throws {
        try core.profiles.save(
            Profile(
                name: name,
                monitorSets: [MonitorSet(monitors: ["A:100x100"])],
                spaceModes: [:],
                settings: settings
            )
        )
        let url = try core.profiles.fileURL(name: name)
        var root = try #require(
            JSONSerialization.jsonObject(with: Data(contentsOf: url))
                as? [String: Any]
        )
        var stored = try #require(root["settings"] as? [String: Any])
        var shelf = try #require(stored["kiwishelf"] as? [String: Any])
        shelf["pocket_visibility"] = nil
        stored["kiwishelf"] = shelf
        root["settings"] = stored
        try JSONSerialization.data(withJSONObject: root).write(to: url)
    }

    @Test("the adoption stamps every profile, then drops the group")
    func adoptionStampsAndStrips() throws {
        let core = try makeGuiCore(capacity: "several")
        try saveLegacy(
            "Focus",
            settings(space: .hidden, app: .hidden),
            in: core
        )
        try saveLegacy(
            "Desk",
            settings(space: .always, app: .always),
            in: core
        )
        #expect(retired(core) == "several")
        core.crossPocketVisibility()
        #expect(
            try core.profiles.read(name: "Focus").settings.kiwishelf
                .pocketVisibility == .auto
        )
        #expect(
            try core.profiles.read(name: "Desk").settings.kiwishelf
                .pocketVisibility == .always
        )
        #expect(retired(core) == nil)
    }

    @Test("a profile that states its Show keeps it")
    func statedProfileKeeps() throws {
        let core = try makeGuiCore(capacity: "one")
        var stated = settings(space: .always, app: .always)
        stated.kiwishelf.pocketVisibility = .auto
        try core.profiles.save(
            Profile(
                name: "Mine",
                monitorSets: [MonitorSet(monitors: ["A:100x100"])],
                spaceModes: [:],
                settings: stated
            )
        )
        core.crossPocketVisibility()
        #expect(
            try core.profiles.read(name: "Mine").settings.kiwishelf
                .pocketVisibility == .auto
        )
    }

    /// Every `gui.json` write drops the retired group, so the
    /// crossing reads it first, ahead of the #1741 and look captures.
    @Test("the crossing runs first at a config load")
    func crossingRunsFirst() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: root.appendingPathComponent(
                "Sources/KiwiDeskCore/App/KiwiCore+Config.swift"
            ),
            encoding: .utf8
        )
        let load = try #require(source.range(of: "func loadConfig()"))
        let body = source[load.upperBound...]
        let cross = try #require(body.range(of: "crossPocketVisibility()"))
        let appWide = try #require(body.range(of: "prepareAppWide()"))
        let save = try #require(body.range(of: "guiConfigStore.save("))
        #expect(cross.lowerBound < appWide.lowerBound)
        #expect(cross.lowerBound < save.lowerBound)
    }
}
