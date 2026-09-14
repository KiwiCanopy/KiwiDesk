import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A re-file into a floating space is an entry (#1177/#1230): the
/// windows a profile switch's partitioning or a prune's
/// forwarding hand a floating space carry the layout's frames of
/// the Space they came from, whatever the receiving space was
/// drawn in. Each re-file primitive records the window it moved
/// (`refiledWindows`) and the next pass gathers the floating
/// space it sits in; a
/// same-profile re-apply re-files nothing and arms nothing. Split
/// from `FloatGatherEntryTests` at the §2.1 ceiling along this
/// seam: that suite is the drawn-mode ledger, this one the
/// re-file arm. One real screen, pinned (#531).
@Suite("Float gather on a re-file (#1177)", .serialized)
@MainActor
struct FloatGatherRepartitionTests {
    private static let bounds = CGRect(
        x: 0,
        y: 25,
        width: 1920,
        height: 1055
    )
    private static let parked = WindowID(1)
    private static let shown = WindowID(2)
    /// Creation order: the last created takes the focus, and
    /// monocle shows the focused member.
    private static let members = [parked, shown]

    /// A pinned core with two windows in the active space `2`, a
    /// monocle space whose `park` hide style parks the unshown
    /// one at the corner — a layout's off-screen frame, the
    /// scrolled-out column's twin. Space `1` exists beside it.
    /// Nil where the host has no screen.
    private func makeCore() -> KiwiCore? {
        guard let screen = NSScreen.main,
            let display = screen.kiwiDisplay
        else { return nil }
        let core = makeTestCore()
        core.tiler.visibleBounds = { _ in Self.bounds }
        core.tiler.allScreenBounds = { [Self.bounds] }
        core.tiler.settings.animations.onRelayout = false
        core.tiler.settings.spaceBarStyle.enabled = false
        core.tiler.settings.borderStyle.enabled = false
        core.tiler.settings.monocle.hideStyle = .park
        core.state.apply(.displaysChanged([display]))
        core.state.workspaces.ensureSpace("1")
        core.state.workspaces.ensureSpace("2")
        core.state.workspaces.activate("2")
        for id in Self.members {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: id,
                        pid: 1,
                        appName: "App",
                        frame: CGRect(
                            x: 100,
                            y: 100,
                            width: 800,
                            height: 600
                        )
                    )
                )
            )
        }
        core.state.workspaces.setMode("2", .monocle)
        core.resolveSpaceDisplays(mainID: display.id)
        return core
    }

    /// The parked member is seeded a grid cell and the shown one
    /// nothing — the visibility scope, applied to a re-file. A
    /// receiving space left unshown parks the shown member and
    /// captures its own state frame, which is not a gather.
    private func expectGathered(_ core: KiwiCore) {
        let shownCapture = core.tiler.stashOriginal(Self.shown)
        #expect(
            shownCapture == nil
                || shownCapture == core.state.windows[Self.shown]?.frame
        )
        let seeded = core.tiler.stashOriginal(Self.parked)
        #expect(seeded != nil)
        // Neither the park's own capture of the state frame (an
        // unshown receiver parks its members too) nor the strand
        // net's centre: a grid cell.
        #expect(seeded != core.state.windows[Self.parked]?.frame)
        #expect(
            seeded
                != FloatRecovery.centred(
                    seeded?.size ?? .zero,
                    in: Self.bounds
                )
        )
    }

    private func profile(
        _ name: String,
        modes: [SpaceID: LayoutMode],
        settings: TilingSettings
    ) -> Profile {
        Profile(
            name: name,
            monitorSets: [],
            spaces: SpaceID.numericLexicalSorted(Array(modes.keys)),
            spaceModes: modes,
            settings: settings
        )
    }

    /// A switch to a profile that does not declare the window's
    /// Space forwards it into the fallback — the prune door.
    @Test(
        "A switch's prune into a floating space gathers",
        .enabled(if: NSScreen.main != nil)
    )
    func switchPruneIsAnEntry() throws {
        let core = try #require(makeCore())
        let settings = core.tiler.settings
        let a = profile(
            "A",
            modes: ["1": .floating, "2": .scrolling],
            settings: settings
        )
        core.apply(profile: a, forceRetile: true)
        // A re-apply of the live profile re-files nothing.
        core.apply(profile: a, forceRetile: true)
        #expect(core.tiler.stashOriginal(Self.parked) == nil)
        core.apply(
            profile: profile("B", modes: ["1": .floating], settings: settings),
            forceRetile: true
        )
        #expect(core.state.workspaces.space(of: Self.parked) == "1")
        expectGathered(core)
        #expect(core.refiledWindows.isEmpty)
    }

    /// The incoming profile's own partitioning moves the window
    /// back into its floating Space — the restore door.
    @Test(
        "A switch's partitioning restore into a floating space gathers",
        .enabled(if: NSScreen.main != nil)
    )
    func switchRestoreIsAnEntry() throws {
        let core = try #require(makeCore())
        let settings = core.tiler.settings
        let modes: [SpaceID: LayoutMode] = ["1": .floating, "2": .monocle]
        let a = profile("A", modes: modes, settings: settings)
        let b = profile("B", modes: modes, settings: settings)
        // A held both windows in its floating `1`.
        core.apply(profile: a, forceRetile: true)
        for id in Self.members {
            core.state.workspaces.add(id, to: "1")
        }
        core.retile(force: true)
        // In B they live in monocle `2`, drawn there.
        core.apply(profile: b, forceRetile: true)
        for id in Self.members {
            core.state.workspaces.add(id, to: "2")
        }
        core.retile(force: true)
        #expect(core.tiler.stashOriginal(Self.parked) == nil)
        // Back to A: its record puts them in `1`, which was drawn
        // floating all along.
        core.apply(profile: a, forceRetile: true)
        #expect(core.state.workspaces.space(of: Self.parked) == "1")
        expectGathered(core)
    }

    /// A prune with no switch at all — the Settings-Save deletion
    /// path — arms the fallback the same way.
    @Test(
        "A prune outside a switch gathers into the fallback",
        .enabled(if: NSScreen.main != nil)
    )
    func barePruneIsAnEntry() throws {
        let core = try #require(makeCore())
        core.state.workspaces.setMode("1", .floating)
        core.retile(force: true)
        #expect(core.drawnSpaceModes["1"] == .floating)
        core.pruneSpaces(keeping: ["1"], orderedBy: ["1"])
        #expect(core.refiledWindows == Set(Self.members))
        core.retile(force: true)
        expectGathered(core)
        #expect(core.refiledWindows.isEmpty)
    }

    /// The arm names the space a re-filed window SITS in: a
    /// re-file into a tiled space is the layout's, and a floating
    /// space that received nothing keeps its own off-region
    /// member where it is.
    @Test(
        "Only the space a re-filed window sits in is armed",
        .enabled(if: NSScreen.main != nil)
    )
    func onlyTheReceiverIsArmed() throws {
        let core = try #require(makeCore())
        let bystander = WindowID(3)
        core.state.windows.upsert(
            ManagedWindow(
                id: bystander,
                pid: 1,
                appName: "App",
                frame: CGRect(x: 2100, y: 100, width: 800, height: 600)
            )
        )
        core.state.workspaces.add(bystander, to: "1")
        core.state.workspaces.setMode("1", .floating)
        core.state.workspaces.ensureSpace("3")
        core.state.workspaces.setMode("3", .bsp)
        core.retile(force: true)
        core.pruneSpaces(keeping: ["1", "3"], orderedBy: ["3", "1"])
        #expect(core.refiledWindows == Set(Self.members))
        core.retile(force: true)
        #expect(core.tiler.stashOriginal(Self.parked) == nil)
        #expect(core.tiler.stashOriginal(bystander) == nil)
    }

    /// A space a re-file merely passed THROUGH is not armed: the
    /// switch's prune forwards into the fallback and the incoming
    /// profile's restore moves the windows on, so a half-off float
    /// already living in the fallback is left where the user put
    /// it.
    @Test(
        "A transit space is not armed",
        .enabled(if: NSScreen.main != nil)
    )
    func transitSpaceIsNotArmed() throws {
        let core = try #require(makeCore())
        let settings = core.tiler.settings
        let bystander = WindowID(3)
        core.state.windows.upsert(
            ManagedWindow(
                id: bystander,
                pid: 1,
                appName: "App",
                frame: CGRect(x: 2100, y: 100, width: 800, height: 600)
            )
        )
        let a = profile(
            "A",
            modes: ["1": .floating, "2": .monocle],
            settings: settings
        )
        let b = profile(
            "B",
            modes: ["1": .floating, "2": .monocle, "3": .bsp],
            settings: settings
        )
        // A: the pair in monocle `2`, the bystander in floating `1`.
        core.apply(profile: a, forceRetile: true)
        core.state.workspaces.add(bystander, to: "1")
        core.retile(force: true)
        // B: the pair moved by hand into its bsp `3`.
        core.apply(profile: b, forceRetile: true)
        for id in Self.members {
            core.state.workspaces.add(id, to: "3")
        }
        core.retile(force: true)
        // Back to A: `3` is pruned into the fallback `1`, and A's
        // own record then moves the pair on to `2` — `1` was only
        // passed through.
        core.apply(profile: a, forceRetile: true)
        #expect(core.state.workspaces.space(of: Self.parked) == "2")
        #expect(core.state.workspaces.space(of: bystander) == "1")
        // Unshown `1` parks it and captures its own state frame,
        // which is not a gather.
        let capture = core.tiler.stashOriginal(bystander)
        #expect(
            capture == nil
                || capture == core.state.windows[bystander]?.frame
        )
    }
}
