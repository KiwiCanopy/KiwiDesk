import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

@MainActor
private func makeCore() -> KiwiCore {
    KiwiCore(
        configDirectory: FileManager.default
            .temporaryDirectory
            .appendingPathComponent(
                "kiwi-core-\(UUID().uuidString)"
            )
    )
}

@MainActor
private func connect(
    _ core: KiwiCore,
    _ displays: [Display]
) {
    for display in displays {
        core.state.workspaces.upsertDisplay(display)
    }
}

/// A display named `name` with a 100x100 frame, so its
/// fingerprint is `"<name>:100x100"`.
private func display(
    _ id: UInt32,
    _ name: String,
    x: CGFloat = 0
) -> Display {
    Display(
        id: DisplayID(id),
        name: name,
        frame: CGRect(x: x, y: 0, width: 100, height: 100)
    )
}

@Suite("Profile commands", .serialized)
@MainActor
struct ProfileCommandTests {
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

    @Test("save_profile onto an existing name updates it")
    func saveUpdates() throws {
        let core = makeCore()
        connect(core, [display(1, "A")])
        core.execute("set_gap_global", args: [.number(30)])
        core.execute(
            "save_profile",
            args: [.string("desk")]
        )
        core.execute("set_gap_global", args: [.number(4)])
        core.execute(
            "save_profile",
            args: [.string("desk")]
        )
        let updated = try core.profiles.read(name: "desk")
        #expect(updated.settings.gapsGlobal == .uniform(4))
        #expect(updated.monitorSets.count == 1)
        // Still one profile, still the count's default.
        #expect(core.profiles.list() == ["desk"])
        #expect(updated.isDefault)
    }

    @Test("Updating onto other hardware appends a set")
    func updateAppendsSet() throws {
        let core = makeCore()
        connect(core, [display(1, "A")])
        core.execute(
            "save_profile",
            args: [.string("laptop")]
        )
        // Same count, different monitor: a second set.
        core.state.workspaces.removeDisplay(DisplayID(1))
        connect(core, [display(2, "B")])
        core.execute(
            "save_profile",
            args: [.string("laptop")]
        )
        let profile = try core.profiles.read(name: "laptop")
        #expect(profile.monitorSets.count == 2)
    }

    @Test("Updating with a different screen count fails")
    func updateCountMismatch() {
        let core = makeCore()
        connect(core, [display(1, "A")])
        core.execute(
            "save_profile",
            args: [.string("single")]
        )
        connect(core, [display(2, "B", x: 100)])
        let response = core.execute(
            "save_profile",
            args: [.string("single")]
        )
        #expect(!response.isSuccess)
    }

    @Test("delete_profile removes and reverts to fallback")
    func deleteProfile() {
        let core = makeCore()
        connect(core, [display(1, "A")])
        core.execute(
            "save_profile",
            args: [.string("gone")]
        )
        #expect(
            core.execute(
                "delete_profile",
                args: [.string("gone")]
            ).isSuccess
        )
        #expect(core.profiles.list().isEmpty)
        // The count now resolves to the built-in Standard.
        #expect(core.profiles.currentStandard != nil)
    }

    @Test("set_default_profile re-designates the count")
    func setDefaultCommand() throws {
        let core = makeCore()
        connect(core, [display(1, "A")])
        core.execute(
            "save_profile",
            args: [.string("alpha")]
        )
        core.execute(
            "save_profile",
            args: [.string("beta")]
        )
        #expect(
            core.execute(
                "set_default_profile",
                args: [.string("beta")]
            ).isSuccess
        )
        #expect(
            core.profiles.defaultProfile(count: 1)?.name
                == "beta"
        )
        #expect(try !core.profiles.read(name: "alpha").isDefault)
    }

    @Test("get_profile_status reports name, standard, dirty")
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
                    "standard": .null,
                    "isDirty": .bool(false),
                ])
        )
    }
}

@Suite("Monitor change matching", .serialized)
@MainActor
struct MonitorChangeTests {
    @Test("Exact set match adopts clean")
    func exactClean() throws {
        let core = makeCore()
        connect(core, [display(1, "A")])
        core.execute(
            "save_profile",
            args: [.string("desk")]
        )
        core.execute("load_profile", args: [.string("desk")])
        core.profiles.adoptStandard(named: "x")

        core.handleMonitorChange()
        #expect(core.profiles.currentName == "desk")
        #expect(!core.profiles.isDirty)
        #expect(core.profiles.currentStandard == nil)
    }

    @Test("Count default loads dirty on unknown monitors")
    func countDefaultDirty() throws {
        let core = makeCore()
        connect(core, [display(1, "A")])
        core.execute(
            "save_profile",
            args: [.string("known")]
        )
        core.state.workspaces.removeDisplay(DisplayID(1))
        connect(core, [display(2, "OTHER")])

        core.handleMonitorChange()
        #expect(core.profiles.currentName == "known")
        #expect(core.profiles.isDirty)
    }

    @Test("No profile composes the built-in Standard")
    func standardFallback() throws {
        let core = makeCore()
        connect(core, [display(1, "A")])

        core.handleMonitorChange()
        #expect(core.profiles.currentName == nil)
        #expect(core.profiles.currentStandard == "Developer")
        #expect(core.profiles.isDirty)
        // The Developer Standard: 4 spaces, stack on 2.
        #expect(
            core.state.workspaces[SpaceID(2)]?.mode == .stack
        )
        #expect(
            core.tiler.settings.gapsGlobal == .uniform(8)
        )
        #expect(
            core.state.workspaces.display(of: SpaceID(1))
                == DisplayID(1)
        )
    }

    @Test("A native-space binding beats matching")
    func bindingWins() throws {
        let core = makeCore()
        connect(core, [display(1, "A")])
        core.execute(
            "save_profile",
            args: [.string("Desk One")]
        )
        core.execute(
            "save_profile",
            args: [.string("Desk Two")]
        )
        core.execute(
            "bind_profile_to_native_space",
            args: [.number(2), .string("Desk Two")]
        )
        NativeSpaces.activeSpaceNumberOverride = 2
        defer {
            NativeSpaces.activeSpaceNumberOverride = nil
        }

        core.handleMonitorChange()
        #expect(core.profiles.currentName == "Desk Two")
    }
}

@Suite("Space placement resolution", .serialized)
@MainActor
struct SpacePlacementTests {
    @Test("Pin beats Main beats positional default")
    func precedence() throws {
        let core = makeCore()
        let left = display(1, "L")
        let right = display(2, "R", x: 100)
        connect(core, [left, right])
        for number in 1...8 {
            core.state.workspaces.ensureSpace(SpaceID(number))
        }
        // Pin space 1 to the right screen even though the
        // 2-screen Standard puts it on main; space 5 follows
        // Main explicitly; space 6 falls to the default (its
        // positional plan: second screen).
        core.spacePins = [SpaceID(1): "R:100x100"]
        core.mainSpaces = [SpaceID(5)]

        core.resolveSpaceDisplays(mainID: DisplayID(1))
        let workspaces = core.state.workspaces
        #expect(
            workspaces.display(of: SpaceID(1)) == DisplayID(2)
        )
        #expect(
            workspaces.display(of: SpaceID(5)) == DisplayID(1)
        )
        #expect(
            workspaces.display(of: SpaceID(6)) == DisplayID(2)
        )
        // Space 2: unpinned, per plan on main.
        #expect(
            workspaces.display(of: SpaceID(2)) == DisplayID(1)
        )
    }

    @Test("Spaces outside the plan land on main")
    func offPlanSpaces() throws {
        let core = makeCore()
        connect(core, [display(1, "A")])
        core.state.workspaces.ensureSpace(SpaceID("mail"))

        core.resolveSpaceDisplays(mainID: DisplayID(1))
        #expect(
            core.state.workspaces.display(of: SpaceID("mail"))
                == DisplayID(1)
        )
    }

    @Test("Loading a profile adopts its live set's pins")
    func applyAdoptsPins() throws {
        let core = makeCore()
        let a = display(1, "A")
        let b = display(2, "B", x: 100)
        connect(core, [a, b])
        core.state.workspaces.ensureSpace(SpaceID(1))
        try core.profiles.save(
            Profile(
                name: "pinned",
                monitorSets: [
                    MonitorSet(
                        monitors: [
                            "A:100x100", "B:100x100",
                        ],
                        spaceMonitorMap: [
                            SpaceID(1): "B:100x100"
                        ]
                    )
                ],
                mainSpaces: [SpaceID(2)],
                spaceModes: ["1": .stack, "2": .bsp],
                settings: TilingSettings()
            )
        )
        core.execute(
            "load_profile",
            args: [.string("pinned")]
        )
        #expect(core.spacePins == [SpaceID(1): "B:100x100"])
        #expect(core.mainSpaces == [SpaceID(2)])
        #expect(
            core.state.workspaces.display(of: SpaceID(1))
                == DisplayID(2)
        )
    }
}
