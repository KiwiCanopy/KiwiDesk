import AppKit
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

// The #1179 half of the quick menu: what a session-only layout
// switch does and does not do to an open Settings draft, and
// what the Keep verb owes that draft. Split from
// `LayoutQuickMenuTests.swift` at the §2.1 sweet spot, and
// deliberately an EXTENSION rather than a second suite — the
// fixture writes a profile under one config directory and the
// base suite is `.serialized` for it, so a second suite would
// race the first under parallel testing.

@MainActor
extension LayoutQuickMenuTests {
    @Test("A quick-menu switch leaves the draft clean")
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
        #expect(core.savedModeForActiveSpace() == nil)
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

    @Test("The Keep row arms on a NON-focused screen's drift")
    func keepArmsOnAnyScreensDrift() throws {
        // Condition 1 of the ruling, and it needs two screens by
        // construction: on one screen `anyScreenHasDrifted` and
        // `activeSpaceHasDrifted` agree, so a single-screen
        // fixture cannot tell the new predicate from the old one
        // (code + architect review, 2026-08-31). The verb writes
        // the WHOLE profile, so a row greyed while another
        // screen's submenu says "not saved to profile" was
        // refusing to do what it was about to do.
        let (_, core) = makeModel()
        let controller = makeController(core)

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
        let cleanMenu = try #require(
            controller.layoutItem().submenu
        )
        let clean = try #require(saveRow(in: cleanMenu))
        #expect(!clean.isEnabled)

        // ...and the OTHER screen's does not.
        core.state.workspaces.setMode(SpaceID("2"), .monocle)
        let info = LayoutMenuInfo.current(from: core)
        #expect(!info.activeSpaceHasDrifted)
        let armedMenu = try #require(
            controller.layoutItem().submenu
        )
        let armed = try #require(saveRow(in: armedMenu))
        #expect(armed.isEnabled)
    }
}
