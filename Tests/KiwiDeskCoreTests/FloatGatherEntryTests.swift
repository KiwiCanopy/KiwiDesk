import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The gather through the retile (#1177): a space whose live
/// mode is floating and whose DRAWN mode was not, with a member
/// out of bounds, owes every member a seed, delivered by the pass's own
/// restore on a shown space and kept by the park on an unshown
/// one. `FloatGatherTests` holds the decision's algebra; this
/// suite is the consumer and the entry ledger, which that one
/// structurally cannot see; `FloatGatherRegionTests` holds the
/// region clauses. One real screen, pinned (#531).
@Suite("Float gather through the retile (#1177)", .serialized)
@MainActor
struct FloatGatherEntryTests {
    private static let bounds = CGRect(
        x: 0,
        y: 25,
        width: 1920,
        height: 1055
    )
    private static let size = CGSize(width: 800, height: 600)
    private static let inside = WindowID(1)
    private static let scrolledOut = WindowID(2)
    private static let partly = WindowID(3)
    private static let space = SpaceID("1")

    private static let frames: [WindowID: CGRect] = [
        inside: CGRect(x: 100, y: 100, width: 800, height: 600),
        scrolledOut: CGRect(x: 2100, y: 100, width: 800, height: 600),
        partly: CGRect(x: 1500, y: 100, width: 800, height: 600),
    ]

    private static var expected: [WindowID: CGRect] {
        FloatGather.targets(
            members: [inside, scrolledOut, partly],
            frames: frames,
            region: bounds,
            minSize: TilingSettings().minWindowSize,
            targetDepth: TilingSettings().quitGridTargetDepth
        )
    }

    /// A core with one shown space in `mode`, holding the three
    /// members at `frames`. Nil where the host has no screen.
    private func makeCore(mode: LayoutMode) -> KiwiCore? {
        guard let screen = NSScreen.main,
            let display = screen.kiwiDisplay
        else { return nil }
        let core = makeTestCore()
        core.tiler.visibleBounds = { _ in Self.bounds }
        core.tiler.allScreenBounds = { [Self.bounds] }
        core.tiler.settings.animations.onRelayout = false
        // Pin the bar with the display (#660): the region is the
        // bounds with the painted strips carved off, and the
        // strip clause below turns one on deliberately.
        core.tiler.settings.spaceBarStyle.enabled = false
        // And the ring: the grid is laid over the grow bound,
        // which reserves the ring's reach on every edge (#1091).
        core.tiler.settings.borderStyle.enabled = false
        core.state.apply(.displaysChanged([display]))
        let members = Self.frames.sorted { $0.key.raw < $1.key.raw }
        for (id, frame) in members {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: id,
                        pid: 1,
                        appName: "App",
                        frame: frame
                    )
                )
            )
        }
        core.resolveSpaceDisplays(mainID: display.id)
        core.state.workspaces.setMode(Self.space, mode)
        return core
    }

    @Test(
        "Entering floating seeds the outside members the grid",
        .enabled(if: NSScreen.main != nil)
    )
    func entryGathersOutsideMembers() throws {
        let core = try #require(makeCore(mode: .scrolling))
        core.settleDrawnSpaceModes()
        core.setSpaceMode(Self.space, .floating)
        core.retile(force: true)
        let expected = Self.expected
        #expect(expected.count == 3)
        #expect(
            core.tiler.stashOriginal(Self.inside) == expected[Self.inside]
        )
        #expect(
            core.tiler.stashOriginal(Self.scrolledOut)
                == expected[Self.scrolledOut]
        )
        #expect(
            core.tiler.stashOriginal(Self.partly) == expected[Self.partly]
        )
        // Delivered by this pass's own restore, not left for a
        // later one.
        #expect(
            core.tiler.recentInstantTarget(Self.scrolledOut)
                == expected[Self.scrolledOut]
        )
    }

    /// A monocle STACK — every member full-size, all on screen —
    /// is a pile and trips the gather (owner ruling 2026-09-14).
    @Test(
        "A shown monocle stack takes the grid",
        .enabled(if: NSScreen.main != nil)
    )
    func shownMonocleStackTakesTheGrid() throws {
        let core = try #require(makeCore(mode: .monocle))
        core.settleDrawnSpaceModes()
        let full = Self.bounds.insetBy(dx: 10, dy: 10)
        let members = [Self.inside, Self.scrolledOut, Self.partly]
        for id in members {
            core.state.windows.updateFrame(id, frame: full)
        }
        core.setSpaceMode(Self.space, .floating)
        core.retile(force: true)
        let grid = FloatGather.targets(
            members: members,
            frames: Dictionary(
                uniqueKeysWithValues: members.map { ($0, full) }
            ),
            region: Self.bounds,
            minSize: core.tiler.settings.minWindowSize,
            targetDepth: core.tiler.settings.quitGridTargetDepth
        )
        #expect(grid.count == 3)
        for id in members {
            #expect(core.tiler.stashOriginal(id) == grid[id])
        }
    }

    /// The seed lands AHEAD of `recoverStrandedFloats`: a shown
    /// pile at the corner — monocle's park — takes the grid, never
    /// the strand net's one centre.
    @Test(
        "A shown corner pile takes the grid, not one centre",
        .enabled(if: NSScreen.main != nil)
    )
    func shownCornerPileTakesTheGrid() throws {
        let core = try #require(makeCore(mode: .monocle))
        core.settleDrawnSpaceModes()
        let parked = TilingEngine.stashFrame(
            CGRect(origin: .zero, size: Self.size),
            in: Self.bounds,
            corner: .bottomRight
        )
        let members = [Self.inside, Self.scrolledOut, Self.partly]
        for id in members {
            core.state.windows.updateFrame(id, frame: parked)
        }
        core.setSpaceMode(Self.space, .floating)
        core.retile(force: true)
        let grid = FloatGather.targets(
            members: members,
            frames: Dictionary(
                uniqueKeysWithValues: members.map { ($0, parked) }
            ),
            region: Self.bounds,
            minSize: core.tiler.settings.minWindowSize,
            targetDepth: core.tiler.settings.quitGridTargetDepth
        )
        let centred = FloatRecovery.centred(Self.size, in: Self.bounds)
        for id in members {
            #expect(core.tiler.stashOriginal(id) == grid[id])
            #expect(core.tiler.stashOriginal(id) != centred)
        }
    }

    @Test(
        "A pass records the mode it drew",
        .enabled(if: NSScreen.main != nil)
    )
    func passRecordsDrawnMode() throws {
        let core = try #require(makeCore(mode: .bsp))
        #expect(core.drawnSpaceModes[Self.space] == nil)
        core.retile()
        #expect(core.drawnSpaceModes[Self.space] == .bsp)
    }

    @Test(
        "The first pass over a floating space gathers nothing",
        .enabled(if: NSScreen.main != nil)
    )
    func firstPassIsNoEntry() throws {
        let core = try #require(makeCore(mode: .floating))
        core.retile()
        #expect(core.tiler.stashOriginal(Self.scrolledOut) == nil)
        #expect(core.drawnSpaceModes[Self.space] == .floating)
    }

    @Test(
        "A reset and re-declare with no pass between is no entry",
        .enabled(if: NSScreen.main != nil)
    )
    func resetAndRedeclareIsNoEntry() throws {
        let core = try #require(makeCore(mode: .floating))
        core.retile()
        core.setSpaceMode(Self.space, .bsp)
        core.setSpaceMode(Self.space, .floating)
        core.retile(force: true)
        #expect(core.tiler.stashOriginal(Self.scrolledOut) == nil)
    }

    @Test(
        "A snapshot replay of the mode is no entry",
        .enabled(if: NSScreen.main != nil)
    )
    func replayIsNoEntry() throws {
        let core = try #require(makeCore(mode: .scrolling))
        core.settleDrawnSpaceModes()
        core.restore(
            StateSnapshot(
                windows: [],
                spaces: [
                    .init(
                        space: Space(
                            id: Self.space,
                            mode: .floating,
                            windows: [],
                            focused: nil
                        )
                    )
                ],
                activeSpace: Self.space.raw
            )
        )
        #expect(core.state.workspaces[Self.space]?.mode == .floating)
        core.retile(force: true)
        #expect(core.tiler.stashOriginal(Self.scrolledOut) == nil)
    }

    @Test(
        "A member is judged on its pending capture, not the corner",
        .enabled(if: NSScreen.main != nil)
    )
    func pendingCaptureIsTheFrameJudged() throws {
        let core = try #require(makeCore(mode: .scrolling))
        core.settleDrawnSpaceModes()
        // Every member a parked flag float whose capture is
        // visible: the corner they sit at is not where they are
        // going, so nothing trips.
        let parked = TilingEngine.stashFrame(
            CGRect(origin: .zero, size: Self.size),
            in: Self.bounds,
            corner: .bottomRight
        )
        // Captures staggered so none contains another (a pile
        // would trip the gather on its own).
        var captures: [WindowID: CGRect] = [:]
        for (index, id) in [Self.inside, Self.scrolledOut, Self.partly]
            .enumerated()
        {
            let capture = CGRect(
                x: 100 + CGFloat(index) * 300,
                y: 100 + CGFloat(index) * 150,
                width: 800,
                height: 600
            )
            captures[id] = capture
            core.state.setFloating(id, true)
            core.state.windows.updateFrame(id, frame: parked)
            core.tiler.seedStash(id, frame: capture)
        }
        core.setSpaceMode(Self.space, .floating)
        core.retile(force: true)
        for (id, capture) in captures {
            #expect(core.tiler.stashOriginal(id) == capture)
        }
    }

    @Test(
        "A fullscreen member is left to its own macOS Space",
        .enabled(if: NSScreen.main != nil)
    )
    func fullscreenMemberIsLeft() throws {
        let core = try #require(makeCore(mode: .scrolling))
        core.settleDrawnSpaceModes()
        core.state.windows.setFullscreen(Self.scrolledOut, true)
        core.setSpaceMode(Self.space, .floating)
        core.retile(force: true)
        #expect(core.tiler.stashOriginal(Self.scrolledOut) == nil)
        #expect(core.tiler.stashOriginal(Self.partly) != nil)
        #expect(core.tiler.stashOriginal(Self.inside) != nil)
    }

    @Test(
        "An unshown space's seed waits for its activation",
        .enabled(if: NSScreen.main != nil)
    )
    func unshownSpaceKeepsTheSeed() throws {
        let core = try #require(makeCore(mode: .scrolling))
        core.settleDrawnSpaceModes()
        let other = SpaceID("2")
        core.state.workspaces.ensureSpace(other)
        core.resolveSpaceDisplays(mainID: NSScreen.main!.kiwiDisplay!.id)
        core.state.workspaces.activate(other)
        core.retile(force: true)
        // Parked, uncaptured: the corner is all the state holds.
        let parked = TilingEngine.stashFrame(
            CGRect(origin: .zero, size: Self.size),
            in: Self.bounds,
            corner: .bottomRight
        )
        for id in [Self.inside, Self.scrolledOut, Self.partly] {
            core.state.windows.updateFrame(id, frame: parked)
        }
        core.setSpaceMode(Self.space, .floating)
        core.retile(force: true)
        let seeded = core.tiler.stashOriginal(Self.inside)
        let target = try #require(seeded)
        #expect(Self.bounds.contains(target))
        // Not delivered while unshown …
        #expect(core.tiler.recentInstantTarget(Self.inside) != target)
        // … and delivered by the activation's pass.
        core.state.workspaces.activate(Self.space)
        core.retile(force: true)
        #expect(core.tiler.recentInstantTarget(Self.inside) == target)
    }
}
