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
/// the leading edge and the space it gave up opened behind it,
/// as if the resize had been a scroll nobody asked for.
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
        // The window the user is resizing holds its place; the
        // freed space goes to the row's far end, not in front of
        // the focus. Both clamps sit clear of this: the row is
        // still 1750pt against a 1000pt viewport.
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

/// The same fix at production altitude: the `resize` verb, the
/// rest `KiwiCore.persistScrollRest` stores, and the retile in
/// between. The layout suite above pins the maths on a fixed
/// display; this one asserts only the invariant the fix exists
/// for — the focused window keeps its place on screen — so it
/// holds on whatever display the host has (#450).
@Suite("Scrolling resize re-anchor, end to end (#966)")
@MainActor
struct ScrollingResizeAnchorEndToEndTests {
    @Test("The resize verb keeps the focused window in place")
    func resizeVerbKeepsFocusedWindowInPlace() throws {
        guard NSScreen.main != nil else { return }
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwidesk-tests-\(UUID().uuidString)"
            )
        let core = makeTestCore(configDirectory: directory)
        // Twenty 800pt slots overflow every display, and a focus
        // ten slots in leaves both clamps far away on any of
        // them — so only the re-anchor can move this window.
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
        let space = try #require(
            core.state.workspaces.space(of: w1)
        )
        core.execute(
            "set_mode",
            args: [.string(space.raw), .string("scrolling")]
        )
        core.execute(
            "scroll.set_slot_size",
            args: [.number(800)]
        )
        let focus = WindowID(10)
        core.state.workspaces.focus(focus, in: space)
        core.retile(animated: false)

        // Park the focused slot 40pt into the viewport: the
        // repro's shape (its leading neighbour clipped) and
        // clear of every clamp on any display width.
        let seeded = try #require(
            core.activeSpace?.scrollRest?.slot?.position
        )
        core.state.workspaces.withSpace(space) {
            $0.scrollRest = ScrollRest(
                offset: -seeded + 40,
                focus: focus,
                position: seeded
            )
        }
        core.execute("resize", args: [.string("x"), .number(-100)])

        let after = try #require(core.activeSpace?.scrollRest)
        let position = try #require(after.slot?.position)
        #expect(after.slot?.window == focus)
        // The row really did move underneath the focus...
        #expect(position < seeded)
        // ...and the focused window did not.
        #expect(abs(after.offset + position - 40) < 0.5)
    }
}
