import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

private let w1 = WindowID(1)
private let w2 = WindowID(2)
private let w3 = WindowID(3)

/// Monocle's `park` hide style (#881): the shown member takes
/// the monocle slot and every other member parks at the stash
/// corner — the space stash's own geometry — so a transparent
/// body or a centered width-bound window (#677) cannot reveal
/// the stack. Display pinned via the context bounds (#531);
/// neighbors pinned per test (#878's threading default is
/// all-open, the single-screen verdict).
@Suite("Monocle park hide style (#881)")
struct MonocleParkLayoutTests {
    let layout = MonocleLayout()

    private func makeContext() -> LayoutContext {
        var context = LayoutContext(
            bounds: CGRect(
                x: 0,
                y: 0,
                width: 1920,
                height: 1080
            ),
            gaps: .uniform(10)
        )
        context.monocle.appBar.enabled = false
        context.monocle.hideStyle = .park
        return context
    }

    /// The stash's own park arithmetic, restated from the
    /// constants rather than the production function, so a
    /// drifted `stashFrame` reds here instead of agreeing with
    /// itself.
    private func parkFrame(
        of size: CGSize,
        in bounds: CGRect,
        left: Bool
    ) -> CGRect {
        CGRect(
            x: left
                ? bounds.minX + TilingEngine.stashPeekX
                    - size.width
                : bounds.maxX - TilingEngine.stashPeekX,
            y: bounds.maxY - TilingEngine.stashPeekY,
            width: size.width,
            height: size.height
        )
    }

    @Test("The focused member shows; the rest park at the corner")
    func focusedShowsOthersPark() throws {
        var context = makeContext()
        context.focused = w2
        let frames = layout.calculateGeometry(
            for: [w1, w2, w3],
            in: context
        )
        let area = context.usable
        #expect(frames[w2] == area)
        // No neighbors: the default corner is bottom-right.
        let parked = parkFrame(
            of: area.size,
            in: context.bounds,
            left: false
        )
        #expect(frames[w1] == parked)
        #expect(frames[w3] == parked)
    }

    @Test("A right neighbor flips the park to the free left corner")
    func rightNeighborParksLeft() throws {
        var context = makeContext()
        context.focused = w1
        context.screenNeighbors = ScreenNeighbors(right: true)
        let frames = layout.calculateGeometry(
            for: [w1, w2],
            in: context
        )
        let area = context.usable
        #expect(
            frames[w2]
                == parkFrame(
                    of: area.size,
                    in: context.bounds,
                    left: true
                )
        )
    }

    @Test("A parked refused-width window parks its OWN size")
    func boundConsumedParkSize() throws {
        // A full-width park of a window the app holds narrower
        // would push its whole body past the peek: the sliver
        // must be computed from the size the window actually
        // has (#677's learned answer).
        var context = makeContext()
        context.focused = w1
        let area = context.usable
        context.sizeBounds[w2] = EffectiveSizeBound(
            width: .init(asked: area.width, answered: 715)
        )
        let frames = layout.calculateGeometry(
            for: [w1, w2],
            in: context
        )
        let parked = try #require(frames[w2])
        #expect(parked.width == 715)
        // Bottom-right anchor: the LEFT edge sits at the peek
        // offset whatever the width, so the sliver stays on
        // screen.
        #expect(
            parked.minX
                == context.bounds.maxX - TilingEngine.stashPeekX
        )
        // And the shown window still centers its learned answer
        // when it is the refused one.
        context.focused = w2
        let shown = try #require(
            layout.calculateGeometry(
                for: [w1, w2],
                in: context
            )[w2]
        )
        #expect(shown.width == 715)
        #expect(abs(shown.midX - area.midX) < 0.01)
    }

    @Test("No anchored member: the front of the carousel shows")
    func noAnchorShowsFirst() throws {
        // A focused float is the anchor but never a member —
        // the space must not park ALL its windows.
        var context = makeContext()
        context.focused = WindowID(99)
        let frames = layout.calculateGeometry(
            for: [w1, w2],
            in: context
        )
        #expect(frames[w1] == context.usable)
        #expect(frames[w1] != frames[w2])
    }

    @Test("The sliver clears an enabled bottom App Bar strip")
    func parkClearsTheBarStrip() throws {
        // The bar renders ABOVE windows on its edge and
        // defaults ENABLED at the bottom — a park anchored to
        // the raw bounds would hide the sliver underneath it
        // (#881 review round).
        var context = makeContext()
        context.monocle.appBar.enabled = true
        context.focused = w1
        let strip = try #require(
            context.monocle.barFrame(
                in: context.usable,
                global: context.appBarStyle
            )
        )
        let frames = layout.calculateGeometry(
            for: [w1, w2],
            in: context
        )
        let parked = try #require(frames[w2])
        // The whole visible band sits above the strip.
        #expect(
            parked.minY + TilingEngine.stashPeekY
                <= strip.minY
        )
        #expect(
            parked.minY
                == strip.minY - TilingEngine.stashPeekY
        )
    }

    @Test("stack keeps every member at the shared frame")
    func stackKeepsSharedFrame() throws {
        var context = makeContext()
        context.monocle.hideStyle = .stack
        context.focused = w1
        let frames = layout.calculateGeometry(
            for: [w1, w2],
            in: context
        )
        #expect(frames[w1] == context.usable)
        #expect(frames[w2] == context.usable)
    }
}

@MainActor
private func makeCore() -> KiwiCore {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "kiwidesk-tests-\(UUID().uuidString)"
        )
    return makeTestCore(configDirectory: directory)
}

/// The shown-member hold (#881, architect round): a focused
/// local float makes `focusAnchor` follow the float, and the
/// engine must keep showing the member the user was on rather
/// than re-deriving the shown member from the array front and
/// physically swapping windows under the float.
@Suite("Monocle park shown-member hold (#881)", .serialized)
@MainActor
struct MonocleParkShownMemberHoldTests {
    @Test("A float taking focus keeps the shown member")
    func floatFocusHoldsShownMember() throws {
        let core = makeCore()
        for id in 1...2 {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(UInt32(id)),
                        pid: pid_t(id),
                        appName: "App\(id)"
                    )
                )
            )
        }
        var float = ManagedWindow(
            id: WindowID(3),
            pid: 3,
            appName: "Float"
        )
        float.isFloating = true
        core.state.apply(.windowCreated(float))
        let space = try #require(
            core.state.workspaces.space(of: WindowID(1))
        )
        _ = core.execute(
            "set_mode",
            args: [.string(space.raw), .string("monocle")]
        )
        _ = core.execute(
            "monocle.set_hide_style",
            args: [.string("park")]
        )
        core.state.workspaces.focus(WindowID(2), in: space)
        #expect(
            core.tiler.layoutInput(state: core.state)?
                .context.focused == WindowID(2)
        )
        // The float takes focus: the anchor follows it, but the
        // context keeps showing the held member.
        core.state.workspaces.focus(WindowID(3), in: space)
        #expect(
            core.tiler.layoutInput(state: core.state)?
                .context.focused == WindowID(2)
        )
        // A tiled focus updates the hold.
        core.state.workspaces.focus(WindowID(1), in: space)
        #expect(
            core.tiler.layoutInput(state: core.state)?
                .context.focused == WindowID(1)
        )
    }
}

/// The instant-switch half of #881: under `park` a monocle
/// focus retile snaps (the `applyInstant` path), keeping
/// today's raise-only feel; under `stack` it stays animated —
/// byte-for-byte today's behavior.
@Suite("Monocle park focus snap (#881)", .serialized)
@MainActor
struct MonocleParkFocusSnapTests {
    @Test("Park snaps the focus retile; stack stays animated")
    func parkSnapsFocusRetile() {
        let core = makeCore()
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: w1, pid: 1, appName: "A")
            )
        )
        let space = core.state.workspaces.space(of: w1)!
        _ = core.execute(
            "set_mode",
            args: [.string(space.raw), .string("monocle")]
        )
        #expect(core.focusRetileAnimated)
        _ = core.execute(
            "monocle.set_hide_style",
            args: [.string("park")]
        )
        #expect(!core.focusRetileAnimated)
        _ = core.execute(
            "monocle.set_hide_style",
            args: [.string("stack")]
        )
        #expect(core.focusRetileAnimated)
    }
}
