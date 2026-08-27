import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

private let w1 = WindowID(1)
private let w2 = WindowID(2)
private let w3 = WindowID(3)
private let w9 = WindowID(9)

private func makeContext(
    focused: WindowID?,
    offset: CGFloat?
) -> LayoutContext {
    var context = LayoutContext(
        bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080),
        gaps: .uniform(10),
        focused: focused
    )
    context.scrollRest = offset.map { ScrollRest(offset: $0) }
    context.scrolling.slotSize = .points(800)
    return context
}

/// A focused window without a slot in the row — floating, or
/// nothing focused at all — must not pan the viewport (#141):
/// there is nothing to scroll into view, so the offset keeps
/// its boundary-clamped previous value instead of snapping to
/// the first slot.
@Suite("Scrolling floating focus")
struct ScrollingFloatingFocusTests {
    @Test("A slotless focus keeps the scrolled offset")
    func slotlessFocusKeepsOffset() {
        // w9 is not in the row; pre-#141 the slot-0 fallback
        // clamped this offset back to 0.
        let offset = ScrollingLayout.viewportRest(
            for: [w1, w2, w3],
            in: makeContext(focused: w9, offset: -300)
        ).offset
        #expect(offset == -300)
    }

    @Test("No focus at all keeps the scrolled offset")
    func nilFocusKeepsOffset() {
        let offset = ScrollingLayout.viewportRest(
            for: [w1, w2, w3],
            in: makeContext(focused: nil, offset: -300)
        ).offset
        #expect(offset == -300)
    }

    @Test("A never-scrolled space rests at the row start")
    func slotlessFocusFreshSpace() {
        let offset = ScrollingLayout.viewportRest(
            for: [w1, w2, w3],
            in: makeContext(focused: w9, offset: nil)
        ).offset
        #expect(offset == 0)
    }

    @Test("The kept offset still respects the row boundary")
    func slotlessFocusBoundaryClamp() {
        // Way past the end of a 3-slot row: the boundary clamp
        // still applies, only the scroll-into-view clamp is
        // skipped.
        let offset = ScrollingLayout.viewportRest(
            for: [w1, w2, w3],
            in: makeContext(focused: w9, offset: -9000)
        ).offset
        let context = makeContext(focused: w9, offset: nil)
        let area = context.scrolling.windowFrame(
            in: context.usable,
            inner: context.gaps.inner,
            global: context.appBarStyle
        )
        let rowLength = 3 * CGFloat(800) + 2 * 10
        #expect(offset == area.width - rowLength)
    }

    @Test("Focusing a floating window does not pan home")
    @MainActor
    func floatingFocusEndToEnd() {
        guard NSScreen.main != nil else { return }
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwidesk-tests-\(UUID().uuidString)"
            )
        let core = makeTestCore(configDirectory: directory)
        // Twenty windows so the row overflows every display width:
        // the offset then stays scrolled on any host, single- or
        // multi-monitor (see the assertion note below, #450).
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
        let space = core.state.workspaces.space(of: w1)!
        core.execute(
            "set_mode",
            args: [.string(space.raw), .string("scrolling")]
        )
        core.execute(
            "scroll.set_slot_size",
            args: [.number(800)]
        )
        // Scroll to the far end, then back to w2: the offset
        // rests scrolled (negative). Once w2 floats it must keep
        // a scrolled position; only the #141 bug would pan it home.
        core.state.workspaces.focus(WindowID(20), in: space)
        core.retile(animated: false)
        core.state.workspaces.focus(w2, in: space)
        core.retile(animated: false)
        let scrolled = core.activeSpace?.scrollRest?.offset
        #expect(scrolled != nil && scrolled! < 0)
        core.execute("make_floating")
        core.retile(animated: false)
        // The floating focus has no slot, so the viewport keeps a
        // boundary-clamped scrolled position instead of the pre-#141
        // slot-0 pan home (which reset the offset to 0 and jumped
        // the row). Asserted as the sign-stable invariant, not the
        // exact pre-float value: floating drops a slot, so on a
        // viewport that leaves the old offset past the shortened
        // row's boundary it legitimately re-clamps by up to one
        // slot. Pinning the exact value coupled the test to
        // NSScreen.main and failed on multi-monitor hosts (#450);
        // the 20-window row overflows any display, so "still
        // scrolled" holds everywhere.
        let afterFloat = core.activeSpace?.scrollRest?.offset
        #expect(afterFloat != nil && afterFloat! < 0)
    }
}
