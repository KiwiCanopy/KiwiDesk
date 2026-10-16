import AppKit
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// What a session-only layout switch does and does not do to an
/// open Settings draft, and what Keep owes that draft (#1179) —
/// Keep as KiwiHub's View side and a Space chip's Layout menu both
/// reach it. `.serialized`: the fixture writes a profile under one
/// config directory.
@Suite("Layout switch and Keep against the draft", .serialized)
@MainActor
struct LayoutKeepDraftTests {
    func makeModel() -> (SettingsModel, KiwiCore) {
        // makeTestCore's default registrar is already the no-op
        // (#565) — this suite asserts nothing about registration.
        let core = makeTestCore()
        try? core.guiConfigStore.save(GuiConfig())
        return (makeTestModel(core: core), core)
    }

    func loadProfile(
        _ core: KiwiCore,
        mode: LayoutMode = .bsp
    ) throws {
        // A valid monitor set is required (decode rejects a
        // profile without one) and it must match a live
        // display, or `load_profile` marks the profile dirty
        // (#36) and the guardrail-3 assertions turn vacuous.
        let frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        core.state.workspaces.upsertDisplay(
            Display(
                id: DisplayID(1),
                name: "A",
                frame: frame,
                visibleFrame: frame
            )
        )
        let profile = Profile(
            name: "test-profile",
            monitorSets: [MonitorSet(monitors: ["A:100x100"])],
            spaces: [SpaceID("1")],
            spaceModes: [SpaceID("1"): mode],
            settings: TilingSettings()
        )
        try core.profiles.save(profile)
        _ = core.execute(
            "load_profile",
            args: [.string("test-profile")]
        )
    }

    @Test("A session layout switch leaves the draft clean")
    func switchLeavesTheDraftClean() throws {
        // #1179: the draft narrates the PROFILE. A session-only
        // layout switch is not an edit, so it must not dirty the
        // draft, arm the pill, or reach the file on the next
        // unrelated Save. Before this the draft seeded its modes
        // from LIVE, which made the switch look like an edit
        // nobody had made.
        let (model, core) = makeModel()

        core.state.workspaces.ensureSpace(SpaceID("1"))
        try loadProfile(core)
        model.reload()
        #expect(!model.isDirty)
        #expect(!model.profileDirty)

        core.state.workspaces.setMode(SpaceID("1"), .monocle)
        model.reload()

        #expect(!model.isDirty)
        #expect(!model.profileDirty)
        // And the draft still reads the SAVED mode, not the one
        // on screen — the seam the leak ran through.
        #expect(model.config.spaceModes[SpaceID("1")] == nil)
    }

    @Test("An unreadable profile leaves the draft on live")
    func unreadableProfileSeedsFromLive() throws {
        // `savedModes` answers "unknown" rather than a phantom
        // `.bsp` for a profile that will not decode, and with no
        // saved answer live is the only truth there is — so the
        // draft must not silently reset every space to bsp.
        let (model, core) = makeModel()

        core.state.workspaces.ensureSpace(SpaceID("1"))
        try loadProfile(core)
        core.state.workspaces.setMode(SpaceID("1"), .monocle)

        try Data("not json".utf8).write(
            to: core.configURL
                .deletingLastPathComponent()
                .appendingPathComponent(
                    "profiles/test-profile.json"
                )
        )
        // The draft's seed reads the FILE (it writes one from the
        // answer); the menus answer from adoption state (#1518).
        #expect(core.savedProfileModes() == nil)
        model.reload()

        #expect(
            model.config.spaceModes[SpaceID("1")] == .monocle
        )
    }

    @Test("A keep moves the baseline and keeps staged edits")
    func keepMovesTheBaseline() throws {
        // #1179 condition 3. The keep writes the live layout
        // into the profile, so the draft's saved BASELINE has to
        // follow — otherwise the next Settings Save commits the
        // pre-keep mode over the layout just kept, which is this
        // issue's own bug one verb along. Staged edits stay
        // staged.
        let (model, core) = makeModel()

        core.state.workspaces.ensureSpace(SpaceID("1"))
        try loadProfile(core)
        model.reload()

        model.config.spaces.append(SpaceID("staged"))
        #expect(model.isDirty)

        core.state.workspaces.setMode(SpaceID("1"), .monocle)
        try core.persistProfile(named: "test-profile", modes: nil)
        model.adoptKeptLayout()

        // The baseline moved onto the kept layout...
        #expect(
            model.cleanConfig.spaceModes[SpaceID("1")]
                == .monocle
        )
        #expect(
            model.config.spaceModes[SpaceID("1")] == .monocle
        )
        // ...and the staged edit is still staged.
        #expect(model.isDirty)
        #expect(
            model.config.spaces.contains(SpaceID("staged"))
        )
    }

    @Test("A keep does not overwrite a staged mode edit")
    func keepLeavesAStagedModeAlone() throws {
        // The other half of condition 3: a space the user HAS
        // edited keeps its staged mode and stays counted as
        // edited — the baseline moves under it, the edit does
        // not.
        let (model, core) = makeModel()

        core.state.workspaces.ensureSpace(SpaceID("1"))
        try loadProfile(core)
        model.reload()

        model.config.spaceModes[SpaceID("1")] = .stack
        #expect(model.isDirty)

        core.state.workspaces.setMode(SpaceID("1"), .monocle)
        try core.persistProfile(named: "test-profile", modes: nil)
        model.adoptKeptLayout()

        #expect(
            model.cleanConfig.spaceModes[SpaceID("1")]
                == .monocle
        )
        #expect(model.config.spaceModes[SpaceID("1")] == .stack)
        #expect(model.isDirty)
    }

    @Test("Keep arms on a NON-focused screen's drift")
    func keepArmsOnAnyScreensDrift() throws {
        // Condition 1 of the ruling, and it needs two screens by
        // construction: on one screen `anyScreenHasDrifted` and
        // `activeSpaceHasDrifted` agree, so a single-screen
        // fixture cannot tell the new predicate from the old one
        // (code + architect review, 2026-08-31). The verb writes
        // the WHOLE profile, so a Keep greyed while another
        // screen's layout was not saved refused to do what it was
        // about to do.
        let (_, core) = makeModel()

        let frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        core.state.workspaces.upsertDisplay(
            Display(
                id: DisplayID(1),
                name: "A",
                frame: frame,
                visibleFrame: frame
            )
        )
        let second = CGRect(x: 100, y: 0, width: 100, height: 100)
        core.state.workspaces.upsertDisplay(
            Display(
                id: DisplayID(2),
                name: "B",
                frame: second,
                visibleFrame: second
            )
        )
        core.state.workspaces.ensureSpace(SpaceID("1"))
        core.state.workspaces.ensureSpace(SpaceID("2"))
        let profile = Profile(
            name: "two-screens",
            monitorSets: [
                MonitorSet(monitors: ["A:100x100", "B:100x100"])
            ],
            spaces: [SpaceID("1"), SpaceID("2")],
            spaceModes: [SpaceID("1"): .bsp, SpaceID("2"): .bsp],
            settings: TilingSettings()
        )
        try core.profiles.save(profile)
        _ = core.execute(
            "load_profile",
            args: [.string("two-screens")]
        )

        // Assigned AFTER the load: `load_profile` re-resolves
        // space-to-display placement, so an assignment made
        // before it does not survive.
        core.state.workspaces.assign(SpaceID("1"), to: DisplayID(1))
        core.state.workspaces.assign(SpaceID("2"), to: DisplayID(2))

        // The FOCUSED screen's space matches the profile...
        core.state.workspaces.activate(SpaceID("1"))
        core.state.workspaces.setMode(SpaceID("1"), .bsp)
        let clean = try #require(
            core.layoutPickerState(for: SpaceID("1"))
        )
        #expect(!clean.keepArmed)

        // ...and the OTHER screen's does not.
        core.state.workspaces.setMode(SpaceID("2"), .monocle)
        let armed = try #require(
            core.layoutPickerState(for: SpaceID("1"))
        )
        #expect(!armed.drifted)
        #expect(armed.keepArmed)
    }
}
