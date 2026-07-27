import Foundation
import Testing

@testable import KiwiDeskCore

@MainActor
private func makeCore() -> KiwiCore {
    makeTestCore(
        configDirectory: FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwi-gui-space-\(UUID().uuidString)"
            )
    )
}

/// A minimal GUI model listing `spaces` with default bsp modes —
/// the shape the Spaces tab produces after add/delete edits.
private func config(spaces: [SpaceID]) -> GuiConfig {
    var config = GuiConfig()
    config.spaces = spaces
    var modes: [SpaceID: LayoutMode] = [:]
    for space in spaces { modes[space] = .bsp }
    config.spaceModes = modes
    return config
}

/// The GUI save/boot half of space reconcile (#77): a Spaces-tab
/// deletion drops the space from live, the sidecar mirrors live,
/// and a bare sidecar space seeds into live at boot.
@Suite("GUI space reconcile", .serialized)
@MainActor
struct GuiSpaceReconcileTests {
    // MARK: - Spaces-tab delete (applyProfileScopedState)

    @Test("Deleting a space prunes it from live; windows rehome")
    func deletePrunesAndRehomes() {
        let core = makeCore()
        core.state.workspaces.ensureSpace(SpaceID("1"))
        core.state.workspaces.ensureSpace(SpaceID("2"))
        core.state.workspaces.add(WindowID(7), to: SpaceID("3"))
        // The model no longer lists "3" (deleted in the tab).
        core.applyProfileScopedState(
            from: config(spaces: [SpaceID("1"), SpaceID("2")])
        )
        #expect(core.state.workspaces[SpaceID("3")] == nil)
        #expect(core.state.workspaces[SpaceID("1")] != nil)
        #expect(core.state.workspaces[SpaceID("2")] != nil)
        // Its window forwarded to the first listed space.
        #expect(
            core.state.workspaces.space(of: WindowID(7))
                == SpaceID("1")
        )
    }

    @Test("Listing every live space prunes nothing")
    func keepAllPrunesNothing() {
        let core = makeCore()
        core.state.workspaces.ensureSpace(SpaceID("1"))
        core.state.workspaces.ensureSpace(SpaceID("2"))
        core.applyProfileScopedState(
            from: config(spaces: [SpaceID("1"), SpaceID("2")])
        )
        #expect(core.state.workspaces[SpaceID("1")] != nil)
        #expect(core.state.workspaces[SpaceID("2")] != nil)
    }

    @Test("A space kept alive by a mode-only reference survives")
    func modeReferenceKeepsSpace() {
        let core = makeCore()
        core.state.workspaces.ensureSpace(SpaceID("1"))
        core.state.workspaces.ensureSpace(SpaceID("2"))
        // "2" isn't in the list but is referenced by a mode — it
        // is an ensured survivor, not a deletion, so it stays.
        var model = config(spaces: [SpaceID("1")])
        model.spaceModes[SpaceID("2")] = .stack
        core.applyProfileScopedState(from: model)
        #expect(core.state.workspaces[SpaceID("2")] != nil)
        #expect(
            core.state.workspaces[SpaceID("2")]?.mode == .stack
        )
    }

    @Test("An empty space list prunes nothing (degenerate guard)")
    func emptyListPrunesNothing() {
        let core = makeCore()
        core.state.workspaces.ensureSpace(SpaceID("1"))
        core.state.workspaces.ensureSpace(SpaceID("2"))
        core.applyProfileScopedState(from: config(spaces: []))
        #expect(core.state.workspaces[SpaceID("1")] != nil)
        #expect(core.state.workspaces[SpaceID("2")] != nil)
    }

    // MARK: - Cold-boot seed (seedGuiSpaces)

    @Test("Boot seeds live from the sidecar's space list, in order")
    func seedsSidecarSpaces() throws {
        let core = makeCore()
        try core.guiConfigStore.save(
            config(spaces: [SpaceID("7"), SpaceID("8")])
        )
        core.seedGuiSpaces()
        #expect(core.state.workspaces[SpaceID("7")] != nil)
        #expect(core.state.workspaces[SpaceID("8")] != nil)
        // Seeded ahead of the core's default space, in list order
        // (a fresh StateCoordinator holds space "1").
        let seeded = [SpaceID("7"), SpaceID("8")]
        let ids = core.state.workspaces.allSpaces.map(\.id)
        #expect(ids.filter { seeded.contains($0) } == seeded)
    }

    @Test("Seeding only adds — a live-only space is not dropped")
    func seedKeepsLiveOnlySpace() throws {
        let core = makeCore()
        core.state.workspaces.ensureSpace(SpaceID("live"))
        try core.guiConfigStore.save(
            config(spaces: [SpaceID("7")])
        )
        core.seedGuiSpaces()
        #expect(core.state.workspaces[SpaceID("live")] != nil)
        #expect(core.state.workspaces[SpaceID("7")] != nil)
    }

    // MARK: - Sidecar mirror (syncGuiSpacesToLive)

    @Test("Mirror writes the live space set into gui.json")
    func mirrorsLiveIntoSidecar() throws {
        let core = makeCore()
        // GUI-managed = sidecar exists and no foreign init.lua
        // (none is written in the temp dir here).
        try core.guiConfigStore.save(config(spaces: [SpaceID("1")]))
        core.state.workspaces.ensureSpace(SpaceID("1"))
        core.state.workspaces.ensureSpace(SpaceID("2"))
        core.syncGuiSpacesToLive()
        let saved = try #require(core.guiConfigStore.load())
        #expect(saved.spaces == [SpaceID("1"), SpaceID("2")])
    }

    @Test("Mirror is a no-op with no sidecar (not GUI-managed)")
    func mirrorNoopWithoutSidecar() {
        let core = makeCore()
        core.state.workspaces.ensureSpace(SpaceID("1"))
        // No sidecar saved -> not GUI-managed -> nothing written.
        core.syncGuiSpacesToLive()
        #expect(core.guiConfigStore.load() == nil)
    }

    // MARK: - In-place edit prune (reapplyIfInEffect, #77 / #18)

    @Test("An in-place edit prunes a space dropped in the session")
    func inPlaceEditPrunes() throws {
        let core = makeCore()
        var start = GuiConfig()
        start.spaces = [SpaceID("1"), SpaceID("2"), SpaceID("3")]
        // Adopt a profile carrying all three spaces, live matches.
        // A non-empty monitor set is required to round-trip
        // through `profiles.save`/`read`.
        let profile = Profile(
            name: "edit",
            monitorSets: [
                MonitorSet(monitors: ["mon-a"], spaceMonitorMap: [:])
            ],
            spaces: start.spaces,
            spaceModes: [
                SpaceID("1"): .bsp,
                SpaceID("2"): .bsp,
                SpaceID("3"): .bsp,
            ],
            settings: TilingSettings()
        )
        try core.profiles.save(profile)
        core.apply(
            profile: profile,
            pruneStaleSpaces: true,
            forceRetile: false
        )
        // The edit session drops "3"; write it and hot-reload.
        try core.overwriteProfile(
            named: "edit",
            with: config(spaces: [SpaceID("1"), SpaceID("2")])
        )
        core.reapplyIfInEffect("edit")
        #expect(core.state.workspaces[SpaceID("3")] == nil)
        #expect(core.state.workspaces[SpaceID("1")] != nil)
        #expect(core.state.workspaces[SpaceID("2")] != nil)
    }

    @Test("A load_profile prune mirrors the live set to gui.json")
    func loadProfileMirrorsSidecar() throws {
        let core = makeCore()
        // GUI-managed: a sidecar exists (no foreign init.lua here).
        try core.guiConfigStore.save(
            config(spaces: [SpaceID("A"), SpaceID("B")])
        )
        core.state.workspaces.ensureSpace(SpaceID("A"))
        core.state.workspaces.ensureSpace(SpaceID("B"))
        try core.profiles.write(
            Profile(
                name: "solo",
                monitorSets: [
                    MonitorSet(
                        monitors: ["m"],
                        spaceMonitorMap: [:]
                    )
                ],
                spaces: [SpaceID("A")],
                spaceModes: [SpaceID("A"): .bsp],
                settings: TilingSettings()
            )
        )
        _ = core.execute("load_profile", args: [.string("solo")])
        // "B" pruned from live and the sidecar now mirrors [A].
        #expect(core.state.workspaces[SpaceID("B")] == nil)
        let saved = try #require(core.guiConfigStore.load())
        #expect(saved.spaces == [SpaceID("A")])
    }

    @Test("Deleting a space under one profile leaves others intact")
    func deletionIsPerProfile() throws {
        let core = makeCore()
        let mon = [
            MonitorSet(monitors: ["m"], spaceMonitorMap: [:])
        ]
        try core.profiles.write(
            Profile(
                name: "one",
                monitorSets: mon,
                spaces: [SpaceID("A"), SpaceID("B")],
                spaceModes: [
                    SpaceID("A"): .bsp,
                    SpaceID("B"): .bsp,
                ],
                settings: TilingSettings()
            )
        )
        let two = Profile(
            name: "two",
            monitorSets: mon,
            spaces: [SpaceID("A"), SpaceID("C")],
            spaceModes: [
                SpaceID("A"): .bsp,
                SpaceID("C"): .bsp,
            ],
            settings: TilingSettings()
        )
        try core.profiles.write(two)
        // Activate "two" and delete the shared space "A" from it.
        core.apply(
            profile: two,
            pruneStaleSpaces: true,
            forceRetile: false
        )
        core.applyProfileScopedState(
            from: config(spaces: [SpaceID("C")])
        )
        #expect(core.state.workspaces[SpaceID("A")] == nil)
        // Profile "one" still declares "A" — each profile is its
        // own file, so the delete never touches the other.
        let reread = try core.profiles.read(name: "one")
        #expect(reread.declaredSpaces.contains(SpaceID("A")))
    }
}
