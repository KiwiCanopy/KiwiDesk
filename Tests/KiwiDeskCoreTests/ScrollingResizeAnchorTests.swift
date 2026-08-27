import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

private let w1 = WindowID(1)
private let w2 = WindowID(2)
private let w3 = WindowID(3)
private let w4 = WindowID(4)
private let w5 = WindowID(5)
private let windows = [w1, w2, w3, w4, w5]

/// A 1000pt usable width (1020 less the 10pt outer gaps), no
/// inner gap, so a 400pt slot puts window `i` at `(i-1) * 400`
/// and five of them overflow to a 2000pt row. Every number
/// below is read off that pinned geometry (#531).
private func makeContext(
    anchor: ScrollingParams.Anchor = .follow,
    focused: WindowID?,
    slot: CGFloat
) -> LayoutContext {
    var context = LayoutContext(
        bounds: CGRect(x: 0, y: 0, width: 1020, height: 1080),
        gaps: .uniform(10),
        focused: focused
    )
    context.scrolling.appBar.enabled = false
    context.scrolling.slotSize = .points(slot)
    context.gaps.inner.horizontal = 0
    context.scrolling.anchor = anchor
    // Pin the floor the slot resolution reasons from (#660):
    // every coordinate below assumes the asked slot survives
    // `max(resolved, minWindowSize)` in `ScrollingLayout.metrics`.
    context.minWindowSize = 300
    return context
}

/// How far into the viewport a window's leading edge sits.
private func lead(
    of window: WindowID,
    in frames: [WindowID: CGRect],
    _ context: LayoutContext
) throws -> CGFloat {
    try #require(frames[window]).minX - context.usable.minX
}

/// Resizing a scrolling slot re-anchors the viewport (#966).
///
/// One slot size serves the whole row, so a resize moves every
/// slot's POSITION along it — and `follow`, which holds the
/// prior offset by design (#66), was left holding a number that
/// now pointed somewhere else: the focused window slid toward
/// the leading edge, as if the resize had been a scroll nobody
/// asked for.
///
/// The fix is a discrimination, so these pin both sides of it:
/// the row moving underneath an unchanged focus re-anchors, a
/// focus change still pans minimally from the offset it had.
@Suite("Scrolling resize re-anchors the viewport (#966)")
struct ScrollingResizeAnchorTests {
    let layout = ScrollingLayout()

    @Test("A slot shrink leaves the focused window in place")
    func shrinkKeepsFocusedWindowInPlace() throws {
        // w3 flush against the trailing edge, w2 whole and w1
        // half-shown behind it: the reported repro's shape —
        // the focus toward the right of the visible run.
        var context = makeContext(focused: w3, slot: 400)
        context.scrollRest = ScrollRest(
            offset: -200,
            focus: w3,
            position: 800
        )
        let before = try lead(
            of: w3,
            in: layout.calculateGeometry(
                for: windows,
                in: context
            ),
            context
        )

        context.scrolling.slotSize = .points(350)
        let frames = layout.calculateGeometry(
            for: windows,
            in: context
        )
        // The window the user is resizing holds its place and
        // the row contracts around it. Both clamps sit clear of
        // this — the row is still 1750pt against a 1000pt
        // viewport — so `rowEndOutranksTheReAnchor` below is
        // where they get to disagree.
        #expect(try lead(of: w3, in: frames, context) == before)
        #expect(
            ScrollingLayout.viewportRest(
                for: windows,
                in: context
            ).offset == -100
        )
    }

    @Test("A focus change still pans from the recorded offset")
    func focusChangePansFromTheOffset() throws {
        // The rest was measured against w3; focusing w2 is a
        // focus change, so the viewport holds its offset and
        // pans only if w2 would be clipped — it isn't, so it
        // does not move at all (#66). Re-anchoring here instead
        // would jump the row by a whole slot.
        var context = makeContext(focused: w3, slot: 400)
        context.scrollRest = ScrollRest(
            offset: -200,
            focus: w3,
            position: 800
        )
        context.focused = w2
        let frames = layout.calculateGeometry(
            for: windows,
            in: context
        )
        #expect(try lead(of: w2, in: frames, context) == 200)
        #expect(
            ScrollingLayout.viewportRest(
                for: windows,
                in: context
            ).offset == -200
        )
    }

    @Test("A rest with no recorded slot holds its offset")
    func restWithoutSlotHoldsItsOffset() throws {
        // Nothing says the offset and the row were measured
        // together — a hand-seeded rest, or one recorded on a
        // pass that placed no slot — so it reads as a focus
        // change, which is what every offset did before #966.
        var context = makeContext(focused: w3, slot: 350)
        context.scrollRest = ScrollRest(offset: -200)
        let frames = layout.calculateGeometry(
            for: windows,
            in: context
        )
        #expect(try lead(of: w3, in: frames, context) == 500)
    }

    @Test("A fixed anchor re-seats the focus across a resize")
    func fixedAnchorReseatsAcrossAResize() throws {
        // The issue's own prediction: `center`/`start`/`end`
        // recompute a resting position on every call, so they
        // never read the recorded offset and cannot drift with
        // it. Seeded with a rest that would drift badly.
        var context = makeContext(
            anchor: .center,
            focused: w3,
            slot: 350
        )
        context.scrollRest = ScrollRest(
            offset: -200,
            focus: w3,
            position: 800
        )
        let frames = layout.calculateGeometry(
            for: windows,
            in: context
        )
        let focused = try #require(frames[w3])
        #expect(abs(focused.midX - context.usable.midX) < 0.01)
    }

    @Test("The row end outranks the re-anchor")
    func rowEndOutranksTheReAnchor() throws {
        // Holding w5's place would need offset -600, which shows
        // 100pt of empty margin past a row that shrank to 1500 in
        // a 1000pt viewport. The boundary clamp wins, so the
        // focus re-anchors only as far as it can and the row's
        // trailing end stays flush with the viewport.
        var context = makeContext(focused: w5, slot: 400)
        context.scrollRest = ScrollRest(
            offset: -1000,
            focus: w5,
            position: 1600
        )
        context.scrolling.slotSize = .points(300)
        let frames = layout.calculateGeometry(
            for: windows,
            in: context
        )
        #expect(try lead(of: w5, in: frames, context) == 700)
        let last = try #require(frames[w5])
        #expect(abs(last.maxX - context.usable.maxX) < 0.01)
    }

    @Test("A window closing ahead of the focus re-anchors too")
    func removalAheadOfTheFocusReAnchors() throws {
        // A resize is not the only thing that moves every slot
        // underneath an unchanged focus. w1 leaving the row
        // pulls w4 back by one slot; the viewport follows so
        // the window nobody touched stays where the user left
        // it.
        var context = makeContext(focused: w4, slot: 400)
        context.scrollRest = ScrollRest(
            offset: -800,
            focus: w4,
            position: 1200
        )
        let frames = layout.calculateGeometry(
            for: [w2, w3, w4, w5],
            in: context
        )
        #expect(try lead(of: w4, in: frames, context) == 400)
    }
}

/// A scrolling space of twenty 800pt slots. Twenty overflow every
/// display, so a focus ten slots in leaves both clamps far away
/// on any of them — only the re-anchor can move that window.
@MainActor
private func makeScrollingCore() -> KiwiCore {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "kiwidesk-tests-\(UUID().uuidString)"
        )
    let core = makeTestCore(configDirectory: directory)
    for id in 1...20 {
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
    let space = core.state.workspaces.space(of: WindowID(1))!
    core.execute(
        "set_mode",
        args: [.string(space.raw), .string("scrolling")]
    )
    core.execute("scroll.set_slot_size", args: [.number(800)])
    return core
}

/// Focuses `window`, retiles, then parks its slot `lead` points
/// into the viewport — the repro's shape (its leading neighbour
/// clipped) and clear of every clamp on any display width.
/// Returns the row position the rest was measured against.
@MainActor
private func seedLead(
    _ lead: CGFloat,
    on window: WindowID,
    of space: SpaceID,
    _ core: KiwiCore
) throws -> CGFloat {
    core.state.workspaces.focus(window, in: space)
    core.retile(animated: false)
    let position = try #require(
        core.activeSpace?.scrollRest?.slot?.position
    )
    core.state.workspaces.withSpace(space) {
        $0.scrollRest = ScrollRest(
            offset: -position + lead,
            focus: window,
            position: position
        )
    }
    return position
}

/// The same fix at production altitude: the `resize` verb, the
/// rest `KiwiCore.persistScrollRest` stores, and the retile in
/// between. The layout suite above pins the maths on a fixed
/// display; this one asserts only the invariant the fix exists
/// for — the focused window keeps its place on screen — so it
/// holds on whatever display the host has (#450).
///
/// It is also the ONLY net for the producer half — the layout
/// suite above injects `context.scrollRest` by hand, so a
/// `viewportRest` that stopped recording the slot leaves every
/// one of those green (guard-prover, 2026-08-27). Hence the
/// screen requirement is an `.enabled(if:)` trait rather than an
/// early `return`: on a headless host this must read as a visible
/// SKIP, never as a green that asserted nothing.
@Suite(
    "Scrolling resize re-anchor, end to end (#966)",
    .enabled(if: NSScreen.main != nil)
)
@MainActor
struct ScrollingResizeAnchorEndToEndTests {
    @Test("The resize verb keeps the focused window in place")
    func resizeVerbKeepsFocusedWindowInPlace() throws {
        let core = makeScrollingCore()
        let space = try #require(
            core.state.workspaces.space(of: WindowID(1))
        )
        let focus = WindowID(10)
        let seeded = try seedLead(40, on: focus, of: space, core)

        core.execute("resize", args: [.string("x"), .number(-100)])

        let after = try #require(core.activeSpace?.scrollRest)
        let position = try #require(after.slot?.position)
        #expect(after.slot?.window == focus)
        // The row really did move underneath the focus...
        #expect(position < seeded)
        // ...and the focused window did not.
        #expect(abs(after.offset + position - 40) < 0.5)
    }

    @Test("Swapping the focus along the row holds its place")
    func swapHoldsTheFocusedWindowInPlace() throws {
        // `swap` re-seats the focused window in the array, which
        // moves its slot without changing which window is
        // focused — so it takes the re-anchor arm, and the
        // window the user is acting on stays put while the row
        // slides past it. Ruled deliberately (#966): no signal
        // inside the layout can separate this from a neighbour
        // closing ahead of the focus, and the same answer is the
        // right one for both — the thing being acted on is the
        // thing that must not jump.
        let core = makeScrollingCore()
        let space = try #require(
            core.state.workspaces.space(of: WindowID(1))
        )
        let focus = WindowID(10)
        let seeded = try seedLead(40, on: focus, of: space, core)

        #expect(
            core.execute("swap", args: [.string("right")])
                .isSuccess
        )
        let after = try #require(core.activeSpace?.scrollRest)
        let position = try #require(after.slot?.position)
        #expect(after.slot?.window == focus)
        // The window moved one slot further along the row...
        #expect(position > seeded)
        // ...and did not move on screen.
        #expect(abs(after.offset + position - 40) < 0.5)
    }
}
