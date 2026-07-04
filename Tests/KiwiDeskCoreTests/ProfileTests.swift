import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

@MainActor
private func makeManager() -> ProfileManager {
    ProfileManager(
        directory: FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwi-profiles-\(UUID().uuidString)"
            )
    )
}

private func makeProfile(
    name: String,
    fingerprints: [String],
    modes: [String: LayoutMode] = ["1": .bsp]
) -> Profile {
    Profile(
        name: name,
        fingerprints: fingerprints,
        monitorCount: fingerprints.count,
        spaceModes: modes,
        settings: TilingSettings(),
        // Whole seconds: profile files store ISO-8601 dates,
        // which drop sub-second precision.
        savedAt: Date(timeIntervalSince1970: 1_780_000_000)
    )
}

@Suite("ProfileManager", .serialized)
@MainActor
struct ProfileManagerTests {
    @Test("Save, list, and load round-trip")
    func roundTrip() throws {
        let manager = makeManager()
        let profile = makeProfile(
            name: "Developer Rig",
            fingerprints: ["LG 27:2560x1440"],
            modes: ["code": .bsp, "music": .floating]
        )
        try manager.save(profile)
        #expect(manager.list() == ["Developer Rig"])
        let loaded = try manager.load(name: "Developer Rig")
        #expect(loaded == profile)
        #expect(manager.currentName == "Developer Rig")
        #expect(!manager.isDirty)
    }

    @Test("Direct fingerprint match wins over count match")
    func matchPriority() throws {
        let manager = makeManager()
        try manager.save(
            makeProfile(
                name: "docked",
                fingerprints: ["LG 27:2560x1440"]
            )
        )
        try manager.save(
            makeProfile(
                name: "other-single",
                fingerprints: ["Dell 24:1920x1080"]
            )
        )
        let match = manager.match(
            fingerprints: ["LG 27:2560x1440"],
            count: 1
        )
        #expect(match?.name == "docked")
    }

    @Test("Count fallback when fingerprints are unknown")
    func countFallback() throws {
        let manager = makeManager()
        try manager.save(
            makeProfile(
                name: "dual",
                fingerprints: ["A:1x1", "B:2x2"]
            )
        )
        let match = manager.match(
            fingerprints: ["C:3x3", "D:4x4"],
            count: 2
        )
        #expect(match?.name == "dual")
        #expect(
            manager.match(
                fingerprints: ["C:3x3"],
                count: 1
            ) == nil
        )
    }

    @Test("Dirty flag lifecycle")
    func dirtyFlag() throws {
        let manager = makeManager()
        manager.markDirty()
        #expect(manager.isDirty)
        try manager.save(
            makeProfile(name: "x", fingerprints: [])
        )
        #expect(!manager.isDirty)
    }
}

@Suite("Profile commands", .serialized)
@MainActor
struct ProfileCommandTests {
    private func makeCore() -> KiwiCore {
        KiwiCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-core-\(UUID().uuidString)"
                )
        )
    }

    @Test("save_profile / load_profile apply settings")
    func saveLoad() {
        let core = makeCore()
        core.execute(
            "set_gap_global",
            args: [.number(30)]
        )
        core.execute(
            "set_mode",
            args: [.string("1"), .string("grid")]
        )
        #expect(
            core.execute(
                "save_profile",
                args: [.string("test")]
            ).isSuccess
        )

        // Diverge, then load back.
        core.execute("set_gap_global", args: [.number(2)])
        core.execute(
            "set_mode",
            args: [.string("1"), .string("stack")]
        )
        #expect(
            core.execute(
                "load_profile",
                args: [.string("test")]
            ).isSuccess
        )
        #expect(
            core.tiler.settings.gapsGlobal == .uniform(30)
        )
        #expect(
            core.state.workspaces[SpaceID(1)]?.mode == .grid
        )
    }

    @Test("get_profile_status reports name and dirty flag")
    func status() {
        let core = makeCore()
        core.execute(
            "save_profile",
            args: [.string("current")]
        )
        let response = core.execute("get_profile_status")
        #expect(
            response.data
                == .object([
                    "name": .string("current"),
                    "isDirty": .bool(false),
                ])
        )
    }
}

@Suite("Monitor fallback resolution")
struct MonitorFallbackTests {
    private let displays = [
        Display(
            id: DisplayID(1),
            name: "Built-in",
            frame: .zero
        ),
        Display(id: DisplayID(2), name: "LG 27", frame: .zero),
    ]

    @Test("Per-space rule beats per-monitor rule")
    func perSpaceWins() {
        let resolved = MonitorFallback.resolve(
            space: SpaceID(1),
            preferredMonitor: "Dell 24",
            displays: displays,
            perSpace: [SpaceID(1): ["LG 27", "Built-in"]],
            perMonitor: ["Dell 24": ["Built-in"]]
        )
        #expect(resolved == DisplayID(2))
    }

    @Test("Per-monitor chain applies without space rule")
    func perMonitorChain() {
        let resolved = MonitorFallback.resolve(
            space: SpaceID(2),
            preferredMonitor: "Dell 24",
            displays: displays,
            perSpace: [:],
            perMonitor: ["Dell 24": ["Built-in"]]
        )
        #expect(resolved == DisplayID(1))
    }

    @Test("Primary display is the final fallback")
    func primaryFallback() {
        let resolved = MonitorFallback.resolve(
            space: SpaceID(3),
            preferredMonitor: nil,
            displays: displays,
            perSpace: [:],
            perMonitor: [:]
        )
        #expect(resolved == DisplayID(1))
    }
}
