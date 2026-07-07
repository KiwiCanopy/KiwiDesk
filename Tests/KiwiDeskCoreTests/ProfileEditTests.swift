import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

// Edit-without-activating (#18): editing a stored profile from
// the dashboard dropdown must write that profile's JSON without
// switching the live layout. Per-file helpers by convention.

@MainActor
private func makeCore() -> KiwiCore {
    KiwiCore(
        configDirectory: FileManager.default
            .temporaryDirectory
            .appendingPathComponent(
                "kiwi-edit-\(UUID().uuidString)"
            )
    )
}

@MainActor
private func connect(_ core: KiwiCore, _ displays: [Display]) {
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

@Suite("Profile editing (#18)", .serialized)
@MainActor
struct ProfileEditTests {
    @Test("overwriteProfile writes without adopting")
    func overwriteIsNonAdopting() throws {
        let core = makeCore()
        connect(core, [display(1, "A")])
        core.execute("save_profile", args: [.string("stored")])
        core.execute("save_profile", args: [.string("active")])
        // "active" is current; "stored" is an idle saved profile.

        var cfg = try core.loadGuiConfig(editing: "stored")
        cfg.settings.gapsGlobal = .uniform(42)
        cfg.spaceModes[SpaceID(1)] = .grid
        try core.overwriteProfile(named: "stored", with: cfg)

        // Live state and current-profile tracking are untouched.
        #expect(core.profiles.currentName == "active")
        #expect(!core.profiles.isDirty)
        // The edit landed in the stored profile's JSON.
        let read = try core.profiles.read(name: "stored")
        #expect(read.settings.gapsGlobal == .uniform(42))
        #expect(read.spaceModes[SpaceID(1)] == .grid)
    }

    @Test("overwriteProfile round-trips the Main role")
    func overwriteRoundTripsMain() throws {
        let core = makeCore()
        connect(core, [display(1, "A")])
        core.execute("save_profile", args: [.string("p")])

        var cfg = try core.loadGuiConfig(editing: "p")
        cfg.mainSpaces = [SpaceID(2)]
        try core.overwriteProfile(named: "p", with: cfg)

        let read = try core.profiles.read(name: "p")
        #expect(read.mainSpaces == [SpaceID(2)])
    }

    @Test("overwriteProfile refreshes the matching set's pins")
    func overwriteUpdatesMatchingSetPins() throws {
        let core = makeCore()
        connect(core, [display(1, "A")])
        core.execute("save_profile", args: [.string("multi")])
        // Same count, other monitor: a second stored set.
        core.state.workspaces.removeDisplay(DisplayID(1))
        connect(core, [display(2, "B")])
        core.execute("save_profile", args: [.string("multi")])
        // Reconnect A so the live monitors match the {A} set.
        core.state.workspaces.removeDisplay(DisplayID(2))
        connect(core, [display(1, "A")])

        var cfg = try core.loadGuiConfig(editing: "multi")
        cfg.spacePins[SpaceID(1)] = "A:100x100"
        try core.overwriteProfile(named: "multi", with: cfg)

        let read = try core.profiles.read(name: "multi")
        #expect(read.monitorSets.count == 2)
        let setA = read.set(matching: ["A:100x100"])
        #expect(setA?.spaceMonitorMap[SpaceID(1)] == "A:100x100")
    }

    @Test("overwriteProfile injects no set for absent monitors")
    func overwriteNeverInjectsLiveSet() throws {
        let core = makeCore()
        connect(core, [display(1, "A")])
        core.execute("save_profile", args: [.string("single")])
        // Live monitors (B) don't match the stored {A} set.
        core.state.workspaces.removeDisplay(DisplayID(1))
        connect(core, [display(2, "B")])

        var cfg = try core.loadGuiConfig(editing: "single")
        cfg.settings.gapsGlobal = .uniform(9)
        try core.overwriteProfile(named: "single", with: cfg)

        let read = try core.profiles.read(name: "single")
        // The connected monitors were not grafted on.
        #expect(read.monitorSets.count == 1)
        #expect(read.set(matching: ["A:100x100"]) != nil)
        #expect(read.set(matching: ["B:100x100"]) == nil)
        #expect(read.settings.gapsGlobal == .uniform(9))
    }

    @Test("loadGuiConfig(editing:) overlays stored, not live")
    func loadEditingReadsStoredTiling() throws {
        let core = makeCore()
        connect(core, [display(1, "A")])
        core.execute("set_gap_global", args: [.number(30)])
        core.execute(
            "set_mode",
            args: [.string("1"), .string("grid")]
        )
        core.execute("save_profile", args: [.string("p")])
        // Diverge the live layout after saving.
        core.execute("set_gap_global", args: [.number(2)])

        let cfg = try core.loadGuiConfig(editing: "p")
        // Reflects the profile's saved tiling, not live's gap 2.
        #expect(cfg.settings.gapsGlobal == .uniform(30))
        #expect(cfg.spaceModes[SpaceID(1)] == .grid)
    }

    @Test("isProfileInEffect true only for the active profile")
    func inEffectPredicate() {
        let core = makeCore()
        connect(core, [display(1, "A")])
        core.execute("save_profile", args: [.string("cur")])
        #expect(core.isProfileInEffect("cur"))
        #expect(!core.isProfileInEffect("other"))
    }

    @Test("reapplyIfInEffect leaves an idle profile's live state")
    func reapplyIdleIsNoop() throws {
        let core = makeCore()
        connect(core, [display(1, "A")])
        core.execute("set_gap_global", args: [.number(30)])
        core.execute("save_profile", args: [.string("stored")])
        core.execute("save_profile", args: [.string("active")])
        // "active" is current; live gap is 30.
        var cfg = try core.loadGuiConfig(editing: "stored")
        cfg.settings.gapsGlobal = .uniform(77)
        try core.overwriteProfile(named: "stored", with: cfg)

        // "stored" is not on screen — no live reapply.
        core.reapplyIfInEffect("stored")
        #expect(core.tiler.settings.gapsGlobal == .uniform(30))
    }

    @Test("Editing a profile never grafts live-only spaces")
    func editKeepsOwnSpaceSet() throws {
        let core = makeCore()
        connect(core, [display(1, "A")])
        core.execute(
            "set_mode",
            args: [.string("1"), .string("grid")]
        )
        core.execute("save_profile", args: [.string("small")])
        #expect(
            try core.profiles.read(name: "small")
                .spaceModes[SpaceID(9)] == nil
        )
        // A live-only space 9 appears; another profile is active.
        core.execute(
            "set_mode",
            args: [.string("9"), .string("stack")]
        )
        core.execute("save_profile", args: [.string("live")])

        var cfg = try core.loadGuiConfig(editing: "small")
        cfg.settings.gapsGlobal = .uniform(5)
        try core.overwriteProfile(named: "small", with: cfg)

        let after = try core.profiles.read(name: "small")
        #expect(after.spaceModes[SpaceID(9)] == nil)
        #expect(after.settings.gapsGlobal == .uniform(5))
    }

    @Test("Editing an absent-monitor profile drops stray pins")
    func absentMonitorDropsPins() throws {
        let core = makeCore()
        connect(core, [display(1, "A")])
        core.execute("save_profile", args: [.string("deskA")])
        // Live monitors change to B: deskA's {A} set won't match.
        core.state.workspaces.removeDisplay(DisplayID(1))
        connect(core, [display(2, "B")])

        var cfg = try core.loadGuiConfig(editing: "deskA")
        // No matching set → no pins come back for editing.
        #expect(cfg.spacePins.isEmpty)
        // Even a stray pin is dropped: {A} untouched, no {B} set.
        cfg.spacePins[SpaceID(1)] = "B:100x100"
        try core.overwriteProfile(named: "deskA", with: cfg)

        let after = try core.profiles.read(name: "deskA")
        #expect(after.monitorSets.count == 1)
        #expect(after.set(matching: ["B:100x100"]) == nil)
        #expect(
            after.set(matching: ["A:100x100"])?
                .spaceMonitorMap[SpaceID(1)] == nil
        )
    }

    @Test("reapplyIfInEffect hot-reloads the active profile")
    func reapplyActive() throws {
        let core = makeCore()
        connect(core, [display(1, "A")])
        core.execute("set_gap_global", args: [.number(30)])
        core.execute("save_profile", args: [.string("cur")])

        var cfg = try core.loadGuiConfig(editing: "cur")
        cfg.settings.gapsGlobal = .uniform(50)
        try core.overwriteProfile(named: "cur", with: cfg)
        // The JSON changed but live state is still the old gap.
        #expect(core.tiler.settings.gapsGlobal == .uniform(30))

        core.reapplyIfInEffect("cur")
        #expect(core.tiler.settings.gapsGlobal == .uniform(50))
    }
}
