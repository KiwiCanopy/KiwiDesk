import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A `.floating` space's members are pushed clear of a painted
/// bar, exactly as a flag-floating window is (#1178).
///
/// Both nets asked `isFloating` alone, so a window in a
/// floating-MODE space got neither: `FloatingLayout` assigns no
/// frames, the drop clamp returned before reaching it, and the
/// retile sweep skipped it — it sat under the strip for good.
///
/// The bar has to be the SPACE Bar: `TilingSettings.appBarHost`
/// hosts an App Bar for `.monocle` and `.scrolling` only, so a
/// floating space can be covered by nothing else.
///
/// `EffectiveFloatTests` holds the predicate's own algebra; this
/// suite is the consumer, which that one structurally cannot see
/// — building the type proves nothing about who asks it.
@Suite("Floating-mode bar clamp (#1178)", .serialized)
@MainActor
struct FloatingModeBarClampTests {
    private static let window = WindowID(1)

    /// A core showing a Space Bar over one space, in `mode`,
    /// holding one window at `frame` that carries no float flag.
    /// Returns nil where the host has no screen to paint on.
    private func makeBarredCore(
        mode: LayoutMode,
        frame: CGRect
    ) -> KiwiCore? {
        guard let screen = NSScreen.main,
            let display = screen.kiwiDisplay
        else { return nil }
        let core = makeTestCore()
        // Pin the display rather than inherit it (#531).
        core.tiler.visibleBounds = { _ in screen.frame }
        core.state.apply(.displaysChanged([display]))
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: Self.window,
                    pid: 1,
                    appName: "FloatApp",
                    frame: frame,
                    isFloating: false
                )
            )
        )
        core.resolveSpaceDisplays(mainID: display.id)
        let space = core.state.workspaces.space(of: Self.window)!
        core.state.workspaces.setMode(space, mode)
        core.tiler.settings.spaceBarStyle.enabled = true
        core.tiler.settings.spaceBarStyle.edge = .top
        core.tiler.settings.spaceBarStyle.thickness = 40
        NativeSpaces.currentSpaceIsUserOverride = { _ in true }
        core.updateSpaceBar()
        return core
    }

    /// The painted strip's own geometry, read from what the
    /// manager actually shows — never re-derived here, which is
    /// the rule the clamp itself obeys.
    private func strip(_ core: KiwiCore) -> CGRect? {
        core.spaceBars.shownStrips.first?.1
    }

    @Test(
        "The retile sweep clamps a floating-MODE member",
        .enabled(if: NSScreen.main != nil)
    )
    func sweepClampsAFloatingModeMember() throws {
        // Overlapping the top strip by construction: origin at
        // the screen's own top-left.
        let screen = try #require(NSScreen.main)
        let frame = CGRect(
            x: screen.frame.minX + 100,
            y: screen.frame.minY,
            width: 400,
            height: 300
        )
        let core = try #require(
            makeBarredCore(mode: .floating, frame: frame)
        )
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        // `#require`, not `if let`: a fixture that painted no bar
        // would make the assertion below pass vacuously, which is
        // the whole thing this suite exists to rule out.
        let painted = try #require(strip(core))

        core.clampFloatsClearOfBars()

        let commanded = try #require(
            core.tiler.recentInstantTarget(Self.window),
            """
            the sweep never wrote a frame — a floating-MODE \
            member is still asked for the flag alone (#1178)
            """
        )
        #expect(commanded.minY >= painted.maxY)
        // Position-only, because this one FITS: the clamp
        // writes `origin` and never `size`. The oversized case
        // is its own test below — asserting an untouched size on
        // a window that could not have been resized proves
        // nothing (code review, 2026-08-31).
        #expect(commanded.size == frame.size)
    }

    @Test(
        "An oversized floating-MODE member is fitted too",
        .enabled(if: NSScreen.main != nil)
    )
    func sweepFitsAnOversizedFloatingModeMember() throws {
        // The size half of the same widening: #1091's fit runs
        // in the same sweep, so a floating-MODE member larger
        // than the region between the bars was equally
        // unreachable. Oversized on purpose, so the fit arm
        // engages rather than being asserted about in absentia.
        let screen = try #require(NSScreen.main)
        let frame = CGRect(
            x: screen.frame.minX,
            y: screen.frame.minY,
            width: screen.frame.width + 400,
            height: screen.frame.height + 400
        )
        let core = try #require(
            makeBarredCore(mode: .floating, frame: frame)
        )
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        _ = try #require(strip(core))
        let region = try #require(core.floatBounds(of: Self.window))

        core.clampFloatsClearOfBars()

        let commanded = try #require(
            core.tiler.recentInstantTarget(Self.window),
            "the oversized floating-MODE member was never fitted"
        )
        #expect(commanded.width <= region.width)
        #expect(commanded.height <= region.height)
    }

    @Test(
        "A drop asks the space it landed in, not the window's own",
        .enabled(if: NSScreen.main != nil)
    )
    func dropAsksTheSpaceItLandedIn() throws {
        // A tiled sticky traveler renders into the active space
        // without belonging to it (#414 v2). Answering from its
        // HOME space would clamp it against strips on a screen
        // it is not on and skip the snap-back that owns it
        // (architect review, 2026-08-31). Asserted on the
        // decision, because the frames the two paths write are
        // indistinguishable once the retile net runs behind
        // them.
        let screen = try #require(NSScreen.main)
        let core = try #require(
            makeBarredCore(
                mode: .floating,
                frame: CGRect(
                    x: screen.frame.minX,
                    y: screen.frame.minY,
                    width: 400,
                    height: 300
                )
            )
        )
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let home = try #require(
            core.state.workspaces.space(of: Self.window)
        )
        #expect(core.dropLandsUnmanaged(Self.window))

        // Same window, same floating home space — but the drop
        // now lands in a space it is not a member of. That space
        // is ALSO floating, which is what makes the membership
        // arm discriminating: with a tiling landed space, nil
        // and `.bsp` answer alike and the arm is inert
        // (guard-prover, 2026-08-31).
        core.state.workspaces.ensureSpace("elsewhere")
        core.state.workspaces.setMode("elsewhere", .floating)
        core.state.workspaces.activate("elsewhere")
        #expect(core.state.workspaces.space(of: Self.window) == home)
        #expect(!core.dropLandsUnmanaged(Self.window))

        // And the same window IS unmanaged once it belongs to
        // the space the drop lands in — so the negative above is
        // membership talking, not the fixture having gone inert.
        core.state.workspaces.add(Self.window, to: "elsewhere")
        #expect(core.dropLandsUnmanaged(Self.window))
    }

    @Test(
        "A fullscreen member is left to its own macOS Space",
        .enabled(if: NSScreen.main != nil)
    )
    func theSweepSkipsAFullscreenMember() throws {
        // A native-fullscreen window keeps its slot (#670) and
        // reaches this sweep only now that a floating-MODE
        // space's members do — poking a fullscreen app with a
        // position clamp AND a size fit is the frame set the
        // stash already refuses. Unguarded when it landed:
        // deleting the clause left all 4300 tests green
        // (guard-prover, 2026-08-31).
        let screen = try #require(NSScreen.main)
        let frame = CGRect(
            x: screen.frame.minX,
            y: screen.frame.minY,
            width: 400,
            height: 300
        )
        let core = try #require(
            makeBarredCore(mode: .floating, frame: frame)
        )
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        _ = try #require(strip(core))

        // The negative twin first, so the assertion below cannot
        // pass for a fixture that never triggers the sweep at
        // all: without the flag this exact frame IS written.
        core.clampFloatsClearOfBars()
        _ = try #require(core.tiler.recentInstantTarget(Self.window))

        core.state.apply(
            .windowFullscreenChanged(Self.window, isFullscreen: true)
        )
        core.tiler.clearInstantTarget(Self.window)
        core.clampFloatsClearOfBars()

        #expect(core.tiler.recentInstantTarget(Self.window) == nil)
    }

    @Test(
        "The drop clamps a floating-MODE member",
        .enabled(if: NSScreen.main != nil)
    )
    func dropClampsAFloatingModeMember() throws {
        let screen = try #require(NSScreen.main)
        let frame = CGRect(
            x: screen.frame.minX + 100,
            y: screen.frame.minY,
            width: 400,
            height: 300
        )
        let core = try #require(
            makeBarredCore(mode: .floating, frame: frame)
        )
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let painted = try #require(strip(core))

        // The drop is where the user meets this: nothing retiles
        // on `.windowMoved`, so a drop that does not clamp leaves
        // the window under the strip until something unrelated
        // retiles.
        core.handleDragEnd(
            Self.window,
            start: frame,
            frame: frame
        )

        let commanded = try #require(
            core.tiler.recentInstantTarget(Self.window),
            "the drop left the window under the strip (#1178)"
        )
        #expect(commanded.minY >= painted.maxY)
    }

    @Test(
        "A tiled member is still left to its layout",
        .enabled(if: NSScreen.main != nil)
    )
    func aTiledMemberIsNotClamped() throws {
        // The negative half: widening the predicate must not
        // make the float net start correcting tiles, whose
        // frames the layout owns.
        let screen = try #require(NSScreen.main)
        let frame = CGRect(
            x: screen.frame.minX + 100,
            y: screen.frame.minY,
            width: 400,
            height: 300
        )
        let core = try #require(
            makeBarredCore(mode: .bsp, frame: frame)
        )
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        _ = try #require(strip(core))

        core.clampFloatsClearOfBars()

        #expect(core.tiler.recentInstantTarget(Self.window) == nil)
    }
}
