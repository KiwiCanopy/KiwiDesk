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

/// A core whose config is GUI-managed (a `gui.json` sidecar
/// exists) — the mode in which the built-in Standard may own
/// tiling when nothing matches (#53).
@MainActor
private func makeGuiManagedCore() -> KiwiCore {
    let core = makeCore()
    try? core.guiConfigStore.save(GuiConfig())
    return core
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

    @Test("Path-escaping profile names are rejected")
    func unsafeNames() {
        let core = makeCore()
        connect(core, [display(1, "A")])
        for bad in ["../escape", "a/b", ".hidden", "   "] {
            #expect(
                !core.execute(
                    "save_profile",
                    args: [.string(bad)]
                ).isSuccess
            )
            #expect(
                !core.execute(
                    "delete_profile",
                    args: [.string(bad)]
                ).isSuccess
            )
            #expect(
                !core.execute(
                    "load_profile",
                    args: [.string(bad)]
                ).isSuccess
            )
        }
        #expect(core.profiles.list().isEmpty)
    }

    @Test("A profile saved for other monitors loads dirty")
    func loadMismatchedDirty() {
        let core = makeCore()
        connect(core, [display(1, "A")])
        core.execute(
            "save_profile",
            args: [.string("desk")]
        )
        core.state.workspaces.removeDisplay(DisplayID(1))
        connect(core, [display(2, "B")])
        core.execute(
            "load_profile",
            args: [.string("desk")]
        )
        #expect(core.profiles.currentName == "desk")
        #expect(core.profiles.isDirty)
    }

    @Test("delete_profile removes and reverts to fallback")
    func deleteProfile() {
        let core = makeGuiManagedCore()
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
