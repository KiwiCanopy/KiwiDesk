import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

private let w1 = WindowID(1)
private let w2 = WindowID(2)

/// The production plumbing that carries `Space.scrollOffset`
/// into and out of the layout (#66). The layout suites inject
/// `context.scrollOffset` by hand, so without these a deleted
/// threading line would keep every suite green while the
/// minimal-pan behavior silently regresses to the anchor.
@Suite("Scroll offset plumbing (#66)")
struct ScrollOffsetPlumbingTests {
    @Test("context(bounds:space:) threads the space's offset")
    func contextCarriesOffset() {
        let settings = TilingSettings()
        var space = Space(
            id: "1",
            mode: .scrolling,
            windows: [w1, w2],
            focused: w1
        )
        space.scrollOffset = -123
        let context = settings.context(
            bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            space: space,
            sticky: []
        )
        #expect(context.scrollOffset == -123)
    }

    @Test("A mode change clears the offset")
    func modeChangeClearsOffset() {
        var manager = WorkspaceManager()
        manager.ensureSpace("1", mode: .scrolling)
        manager.withSpace("1") { $0.scrollOffset = -400 }
        manager.setMode("1", .bsp)
        #expect(manager["1"]?.mode == .bsp)
        #expect(manager["1"]?.scrollOffset == nil)
    }

    @Test("A single tiled window preserves the scroll offset")
    func singleWindowPreservesOffset() {
        // Float one of two scrolled windows and the row drops to
        // one tiled window: `viewportOffset` must return the saved
        // offset, not 0, or unfloating rebuilds the row from home
        // (#155). `calculateGeometry` ignores it for one window,
        // so preserving it is free.
        let settings = TilingSettings()
        var space = Space(
            id: "1",
            mode: .scrolling,
            windows: [w1],
            focused: w1
        )
        space.scrollOffset = -400
        let context = settings.context(
            bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            space: space,
            sticky: []
        )
        #expect(
            ScrollingLayout.viewportOffset(for: [w1], in: context)
                == -400
        )
    }

    @Test("A same-mode set preserves the offset")
    func sameModeSetPreservesOffset() {
        // Profile / GUI applies call `setMode` densely over all
        // live spaces on every apply; a same-mode set clearing
        // the offset would snap every scrolling viewport home
        // whenever an unrelated setting is edited.
        var manager = WorkspaceManager()
        manager.ensureSpace("1", mode: .scrolling)
        manager.withSpace("1") { $0.scrollOffset = -400 }
        manager.setMode("1", .scrolling)
        #expect(manager["1"]?.scrollOffset == -400)
    }
}
