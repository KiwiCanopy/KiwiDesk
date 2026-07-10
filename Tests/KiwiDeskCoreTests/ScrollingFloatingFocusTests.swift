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
    scrollOffset: CGFloat?
) -> LayoutContext {
    var context = LayoutContext(
        bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080),
        gaps: .uniform(10),
        focused: focused
    )
    context.scrollOffset = scrollOffset
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
        let offset = ScrollingLayout.viewportOffset(
            for: [w1, w2, w3],
            in: makeContext(focused: w9, scrollOffset: -300)
        )
        #expect(offset == -300)
    }

    @Test("No focus at all keeps the scrolled offset")
    func nilFocusKeepsOffset() {
        let offset = ScrollingLayout.viewportOffset(
            for: [w1, w2, w3],
            in: makeContext(focused: nil, scrollOffset: -300)
        )
        #expect(offset == -300)
    }

    @Test("A never-scrolled space rests at the row start")
    func slotlessFocusFreshSpace() {
        let offset = ScrollingLayout.viewportOffset(
            for: [w1, w2, w3],
            in: makeContext(focused: w9, scrollOffset: nil)
        )
        #expect(offset == 0)
    }

    @Test("The kept offset still respects the row boundary")
    func slotlessFocusBoundaryClamp() {
        // Way past the end of a 3-slot row: the boundary clamp
        // still applies, only the scroll-into-view clamp is
        // skipped.
        let offset = ScrollingLayout.viewportOffset(
            for: [w1, w2, w3],
            in: makeContext(focused: w9, scrollOffset: -9000)
        )
        let context = makeContext(focused: w9, scrollOffset: nil)
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
        let core = KiwiCore(configDirectory: directory)
        for id in 1...5 {
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
        // Scroll far, then back to w2: the offset rests at
        // w2's left-visible edge — scrolled, but well inside
        // the boundary of the row even after one slot floats
        // out of it, so only the #141 bug could move it.
        core.state.workspaces.focus(WindowID(5), in: space)
        core.retile(animated: false)
        core.state.workspaces.focus(w2, in: space)
        core.retile(animated: false)
        let scrolled = core.activeSpace?.scrollOffset
        #expect(scrolled != nil && scrolled! < 0)
        core.execute("make_floating")
        core.retile(animated: false)
        // Pre-#141 the slot-0 fallback panned the viewport
        // home and persisted 0 — the tiled row visibly jumped.
        #expect(core.activeSpace?.scrollOffset == scrolled)
    }
}
