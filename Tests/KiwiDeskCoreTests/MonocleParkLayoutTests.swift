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
