import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A restore keeps the snapshot frame of every window it could
/// not set (#1362) — an id the boot scan had not tracked when the
/// replay ran — and pays it at that window's ARRIVAL through the
/// stash seed, so the arrival retile delivers it on a shown space
/// and the park keeps it for the activation on an unshown one.
/// Without it a slow app's window kept the frame the boot scan
/// tiled it at, on the main display, while its Space was a
/// floating one on the other display that assigns nothing.
@Suite("Restored frame debt (#1362)", .serialized)
@MainActor
struct RestoredFrameDebtTests {
    private static let bounds = CGRect(
        x: 0,
        y: 25,
        width: 1920,
        height: 1055
    )
    private static let tracked = WindowID(1)
    private static let late = WindowID(2)
    private static let owed = CGRect(
        x: 300,
        y: 200,
        width: 800,
        height: 600
    )
    /// The main-screen tile the scan left the late window at.
    private static let tile = CGRect(
        x: 6,
        y: 68,
        width: 900,
        height: 900
    )

    private func window(_ id: WindowID, frame: CGRect) -> ManagedWindow {
        ManagedWindow(id: id, pid: 1, appName: "App", frame: frame)
    }

    private func record(
        _ id: WindowID,
        frame: CGRect
    ) -> StateSnapshot.WindowRecord {
        .init(id: id, frame: frame)
    }

    private func spaceRecord(
        _ space: SpaceID,
        mode: LayoutMode,
        windows: [WindowID]
    ) -> StateSnapshot.SpaceRecord {
        .init(
            space: Space(
                id: space,
                mode: mode,
                windows: windows,
                focused: nil
            )
        )
    }

    /// A pinned core with `tracked` in the active space `1` and
    /// a second space `2` in `mode`, both on the one display.
    private func makeCore(mode: LayoutMode) -> KiwiCore? {
        guard let screen = NSScreen.main,
            let display = screen.kiwiDisplay
        else { return nil }
        let core = makeTestCore()
        core.tiler.visibleBounds = { _ in Self.bounds }
        core.tiler.allScreenBounds = { [Self.bounds] }
        core.tiler.settings.animations.onRelayout = false
        core.tiler.settings.spaceBarStyle.enabled = false
        core.state.apply(.displaysChanged([display]))
        core.state.apply(
            .windowCreated(
                window(Self.tracked, frame: Self.owed)
            )
        )
        core.state.workspaces.ensureSpace(SpaceID("2"))
        core.resolveSpaceDisplays(mainID: display.id)
        core.state.workspaces.setMode(SpaceID("2"), mode)
        return core
    }

    @Test("The debt is filed for an untracked id in a living Space")
    func debtIsFiledForTheUntracked() throws {
        let core = try #require(makeCore(mode: .floating))
        let corner = TilingEngine.stashFrame(
            Self.owed,
            in: Self.bounds,
            corner: .bottomRight
        )
        let strayInDeadSpace = WindowID(3)
        let strayAtCorner = WindowID(4)
        core.restore(
            StateSnapshot(
                windows: [
                    record(Self.tracked, frame: Self.owed),
                    record(Self.late, frame: Self.owed),
                    record(strayInDeadSpace, frame: Self.owed),
                    record(strayAtCorner, frame: corner),
                ],
                spaces: [
                    spaceRecord("1", mode: .bsp, windows: [Self.tracked]),
                    spaceRecord(
                        "2",
                        mode: .floating,
                        windows: [Self.late, strayAtCorner]
                    ),
                    spaceRecord(
                        "9",
                        mode: .bsp,
                        windows: [strayInDeadSpace]
                    ),
                ],
                activeSpace: "1"
            )
        )
        // The tracked one was set, not owed; a corner is no
        // original; a Space the profile dropped files nothing.
        #expect(core.state.restoredFrames == [Self.late: Self.owed])
    }

    @Test("The arrival consumes the debt once")
    func arrivalConsumesOnce() throws {
        let core = try #require(makeCore(mode: .floating))
        core.state.restoredFrames[Self.late] = Self.owed
        core.state.remember(Self.late, in: "2")
        let first = core.state.apply(
            .windowCreated(window(Self.late, frame: Self.tile))
        )
        #expect(first.restoredFrame == Self.owed)
        #expect(core.state.restoredFrames[Self.late] == nil)
        core.state.apply(
            .windowDestroyed(Self.late, wasMinimized: false)
        )
        let second = core.state.apply(
            .windowCreated(window(Self.late, frame: Self.tile))
        )
        #expect(second.restoredFrame == nil)
    }

    @Test("The #634 reset and the away retirement drop it")
    func resetsDropIt() {
        var state = StateCoordinator(defaultSpace: "1")
        state.restoredFrames[Self.late] = Self.owed
        state.forgetAway(Self.late)
        #expect(state.restoredFrames[Self.late] == nil)
        state.restoredFrames[Self.late] = Self.owed
        state.forgetRememberedSpaces()
        #expect(state.restoredFrames.isEmpty)
    }

    /// The pay: seeded at the arrival, delivered by the arrival
    /// retile's own restore pass where the Space is shown.
    @Test(
        "A late arrival on a shown floating Space takes its frame",
        .enabled(if: NSScreen.main != nil)
    )
    func shownSpaceDeliversAtArrival() throws {
        let core = try #require(makeCore(mode: .floating))
        core.state.workspaces.activate("2")
        core.restore(
            StateSnapshot(
                windows: [record(Self.late, frame: Self.owed)],
                spaces: [
                    spaceRecord("2", mode: .floating, windows: [Self.late])
                ],
                activeSpace: "2"
            )
        )
        core.handle(.windowCreated(window(Self.late, frame: Self.tile)))
        #expect(core.state.workspaces.space(of: Self.late) == "2")
        #expect(core.tiler.stashOriginal(Self.late) == Self.owed)
        #expect(core.tiler.recentInstantTarget(Self.late) == Self.owed)
    }

    /// The park keeps the seed — its capture guard is nil-only —
    /// so the activation delivers what the arrival could not.
    @Test(
        "A late arrival into an unshown Space is paid at activation",
        .enabled(if: NSScreen.main != nil)
    )
    func unshownSpacePaysAtActivation() throws {
        let core = try #require(makeCore(mode: .floating))
        core.restore(
            StateSnapshot(
                windows: [record(Self.late, frame: Self.owed)],
                spaces: [
                    spaceRecord("2", mode: .floating, windows: [Self.late])
                ],
                activeSpace: "1"
            )
        )
        core.handle(.windowCreated(window(Self.late, frame: Self.tile)))
        #expect(core.state.workspaces.space(of: Self.late) == "2")
        #expect(core.tiler.stashOriginal(Self.late) == Self.owed)
        // Parked, not delivered, while its Space is unshown (the
        // park picks the REAL screen, so the corner itself is the
        // host's — tests.md's half-pinned fixture).
        let parked = try #require(
            core.tiler.recentInstantTarget(Self.late)
        )
        #expect(parked != Self.owed)
        #expect(parked.size == Self.tile.size)
        core.state.workspaces.activate("2")
        core.retile(force: true)
        #expect(core.tiler.recentInstantTarget(Self.late) == Self.owed)
    }

    /// A tiled Space's layout outranks the seed: the debt is a
    /// no-op there rather than a fight.
    @Test(
        "A late arrival into a tiled Space is the layout's",
        .enabled(if: NSScreen.main != nil)
    )
    func tiledSpaceDropsTheSeed() throws {
        let core = try #require(makeCore(mode: .bsp))
        core.state.workspaces.activate("2")
        core.restore(
            StateSnapshot(
                windows: [record(Self.late, frame: Self.owed)],
                spaces: [
                    spaceRecord("2", mode: .bsp, windows: [Self.late])
                ],
                activeSpace: "2"
            )
        )
        core.handle(.windowCreated(window(Self.late, frame: Self.tile)))
        #expect(core.tiler.stashOriginal(Self.late) == nil)
        #expect(core.tiler.recentInstantTarget(Self.late) != Self.owed)
    }
}
