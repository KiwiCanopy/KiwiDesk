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
        try core.persistProfile(named: "test-profile")
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
        try core.persistProfile(named: "test-profile")
        model.adoptKeptLayout()

        #expect(
            model.cleanConfig.spaceModes[SpaceID("1")]
                == .monocle
        )
        #expect(model.config.spaceModes[SpaceID("1")] == .stack)
        #expect(model.isDirty)
    }
}
