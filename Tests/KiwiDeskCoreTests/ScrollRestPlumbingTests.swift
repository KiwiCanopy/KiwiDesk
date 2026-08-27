import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

private let w1 = WindowID(1)
private let w2 = WindowID(2)

/// The production plumbing that carries `Space.scrollRest`
/// into and out of the layout (#66, #966). The layout suites
/// inject `context.scrollRest` by hand, so without these a
/// deleted threading line would keep every suite green while
/// the minimal-pan behavior silently regresses to the anchor —
/// and a rest stored without its slot would leave `follow`
/// unable to tell a focus change from a resize.
@Suite("Scroll rest plumbing (#66)")
struct ScrollRestPlumbingTests {
    @Test("context(bounds:space:) threads the space's rest")
    func contextCarriesRest() {
        let settings = TilingSettings()
        var space = Space(
            id: "1",
            mode: .scrolling,
            windows: [w1, w2],
            focused: w1
        )
        // Seeded WITH a slot: a `context` that threaded only
        // the offset and re-wrapped it would pass a slotless
        // fixture (#966).
        space.scrollRest = ScrollRest(
            offset: -123,
            focus: w2,
            position: 800,
            span: 800
        )
        let context = settings.context(
            bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            space: space,
            sticky: []
        )
        #expect(
            context.scrollRest
                == ScrollRest(
                    offset: -123,
                    focus: w2,
                    position: 800,
                    span: 800
                )
        )
    }

    @Test("A mode change clears the rest")
    func modeChangeClearsRest() {
        var manager = WorkspaceManager()
        manager.ensureSpace("1", mode: .scrolling)
        manager.withSpace("1") {
            $0.scrollRest = ScrollRest(offset: -400)
        }
        manager.setMode("1", .bsp)
        #expect(manager["1"]?.mode == .bsp)
        #expect(manager["1"]?.scrollRest == nil)
    }

    @Test("A single tiled window preserves the scroll rest")
    func singleWindowPreservesRest() {
        // Float one of two scrolled windows and the row drops to
        // one tiled window: `viewportRest` must return the saved
        // rest, not 0, or unfloating rebuilds the row from home
        // (#155). `calculateGeometry` ignores it for one window,
        // so preserving it is free.
        let settings = TilingSettings()
        var space = Space(
            id: "1",
            mode: .scrolling,
            windows: [w1],
            focused: w1
        )
        space.scrollRest = ScrollRest(
            offset: -400,
            focus: w1,
            position: 800,
            span: 800
        )
        let context = settings.context(
            bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            space: space,
            sticky: []
        )
        #expect(
            ScrollingLayout.viewportRest(for: [w1], in: context)
                == ScrollRest(
                    offset: -400,
                    focus: w1,
                    position: 800,
                    span: 800
                )
        )
    }

    @Test("A same-mode set preserves the rest")
    func sameModeSetPreservesRest() {
        // Profile / GUI applies call `setMode` densely over all
        // live spaces on every apply; a same-mode set clearing
        // the rest would snap every scrolling viewport home
        // whenever an unrelated setting is edited.
        var manager = WorkspaceManager()
        manager.ensureSpace("1", mode: .scrolling)
        manager.withSpace("1") {
            $0.scrollRest = ScrollRest(offset: -400)
        }
        manager.setMode("1", .scrolling)
        #expect(manager["1"]?.scrollRest == ScrollRest(offset: -400))
    }
}
