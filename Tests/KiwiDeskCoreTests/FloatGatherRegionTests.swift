import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The gather's two regions through the retile (#1177): the
/// JUDGMENT takes `floatBounds` — the correctness bound — and
/// the grid is laid in `floatGrowBounds`, the ring reserved, so
/// the clamp has no push left and a member flush with a bare
/// screen edge stays. Split from `FloatGatherEntryTests` at the
/// §2.1 ceiling along this seam. One real screen, pinned (#531).
@Suite("Float gather regions (#1177)", .serialized)
@MainActor
struct FloatGatherRegionTests {
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

    /// The region is `floatGrowBounds`: the painted strip carved
    /// off and the ring's reach reserved before the grid is laid
    /// (#1091/#242), so the clamp has no push left to make.
    @Test(
        "The gathered frames clear the painted strip and the ring",
        .enabled(if: NSScreen.main != nil)
    )
    func gatheredFramesClearTheStrip() throws {
        let core = try #require(makeCore(mode: .scrolling))
        core.settleDrawnSpaceModes()
        // The ring ON here, deliberately: with it off the grow
        // bound IS the correctness bound and the clause cannot
        // tell them apart (guard-prover).
        core.tiler.settings.borderStyle.enabled = true
        #expect(core.floatRingInset > 0)
        core.tiler.settings.spaceBarStyle.enabled = true
        core.tiler.settings.spaceBarStyle.edge = .top
        core.tiler.settings.spaceBarStyle.thickness = 40
        core.updateSpaceBar()
        let strip = try #require(
            core.spaceBars.shownStrips.first?.1,
            "no bar painted — the clause would pass vacuously"
        )
        core.setSpaceMode(Self.space, .floating)
        core.retile(force: true)
        let seeded = try #require(
            core.tiler.stashOriginal(Self.scrolledOut)
        )
        // Equality over the CARVED region, not `minY >= strip`:
        // the clamp sweep rescues a grid laid over the bare
        // bounds by re-seeding the pushed cell, so a bound alone
        // stayed green on that mutation (guard-prover).
        let region = try #require(core.floatBounds(on: Self.space))
        let grid = try #require(core.floatGrowBounds(on: Self.space))
        #expect(grid.minY >= strip.maxY)
        let carved = FloatGather.targets(
            members: [Self.inside, Self.scrolledOut, Self.partly],
            frames: Self.frames,
            region: region,
            grid: grid,
            minSize: core.tiler.settings.minWindowSize,
            targetDepth: core.tiler.settings.quitGridTargetDepth
        )
        #expect(seeded == carved[Self.scrolledOut])
        let bare = FloatGather.targets(
            members: [Self.inside, Self.scrolledOut, Self.partly],
            frames: Self.frames,
            region: try #require(core.floatBounds(on: Self.space)),
            minSize: core.tiler.settings.minWindowSize,
            targetDepth: core.tiler.settings.quitGridTargetDepth
        )
        #expect(seeded != bare[Self.scrolledOut])
        // And the pass's own clamp sweep left the capture alone.
        core.clampFloatsClearOfBars()
        #expect(core.tiler.stashOriginal(Self.scrolledOut) == seeded)
    }

    /// The JUDGMENT takes the correctness bound: a member flush
    /// with a bare screen edge, where no clamp pushes, is inside
    /// even with the ring's reserve on.
    @Test(
        "A member flush with a screen edge stays, ring on",
        .enabled(if: NSScreen.main != nil)
    )
    func flushEdgeMemberStaysWithRingOn() throws {
        let core = try #require(makeCore(mode: .scrolling))
        core.settleDrawnSpaceModes()
        core.tiler.settings.borderStyle.enabled = true
        #expect(core.floatRingInset > 0)
        let flush = CGRect(
            x: Self.bounds.maxX - 800,
            y: Self.bounds.maxY - 600,
            width: 800,
            height: 600
        )
        core.state.windows.updateFrame(Self.inside, frame: flush)
        core.setSpaceMode(Self.space, .floating)
        core.retile(force: true)
        #expect(core.tiler.stashOriginal(Self.inside) == nil)
        #expect(core.tiler.stashOriginal(Self.scrolledOut) != nil)
    }
}
