import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

private let w1 = WindowID(1)
private let w2 = WindowID(2)

private func makeContext(
    bounds: CGRect = CGRect(x: 0, y: 0, width: 1920, height: 1080),
    gaps: Gaps = .uniform(10)
) -> LayoutContext {
    var context = LayoutContext(
        bounds: bounds,
        gaps: gaps,
        focused: w1
    )
    // Isolate the slot mechanics from the now-default app bar.
    context.scrolling.appBar.enabled = false
    return context
}

/// "If one window, fill the screen" (#1389), default ON — the
/// drawing every profile had before the toggle existed. OFF keeps
/// the lone window at the size a second arrival would leave it,
/// so the second window moves nothing already open.
@Suite("Fill when alone (#1389)")
struct FillWhenAloneTests {
    @Test("Scrolling: the default fills a lone window")
    func scrollingDefaultFills() {
        let context = makeContext()
        #expect(context.scrolling.fillWhenAlone)
        let frames = ScrollingLayout().calculateGeometry(
            for: [w1],
            in: context
        )
        #expect(frames[w1] == context.usable)
    }

    @Test("Scrolling off: a lone window keeps the slot size")
    func scrollingOffKeepsSlot() throws {
        var context = makeContext()
        context.scrolling.fillWhenAlone = false
        context.scrolling.slotSize = .points(600)
        let frames = ScrollingLayout().calculateGeometry(
            for: [w1],
            in: context
        )
        let only = try #require(frames[w1])
        #expect(only.width == 600)
        #expect(only.height == context.usable.height)
        // The one slot the row has sits where the row starts.
        #expect(only.minX == context.usable.minX)
    }

    @Test("Scrolling off: the slot is the one a neighbour joins")
    func scrollingOffSlotIsStable() throws {
        var context = makeContext()
        context.scrolling.fillWhenAlone = false
        context.scrolling.slotSize = .fraction(0.5)
        let alone = try #require(
            ScrollingLayout().calculateGeometry(
                for: [w1],
                in: context
            )[w1]
        )
        let joined = try #require(
            ScrollingLayout().calculateGeometry(
                for: [w1, w2],
                in: context
            )[w1]
        )
        #expect(alone == joined)
    }

    @Test("Stack: the default fills a lone master")
    func stackDefaultFills() {
        let context = makeContext()
        #expect(context.stack.fillWhenAlone)
        let frames = StackLayout().calculateGeometry(
            for: [w1],
            in: context
        )
        #expect(frames[w1] == context.usable)
    }

    @Test("Stack off: a lone master keeps the master zone")
    func stackOffKeepsZone() throws {
        var context = makeContext()
        context.stack.fillWhenAlone = false
        let alone = try #require(
            StackLayout().calculateGeometry(
                for: [w1],
                in: context
            )[w1]
        )
        let joined = try #require(
            StackLayout().calculateGeometry(
                for: [w1, w2],
                in: context
            )[w1]
        )
        // Byte-identical to the zone a second window leaves it.
        #expect(alone == joined)
        #expect(abs(alone.width - 1890 * 0.6) < 0.01)
    }

    @Test("Stack off: the zone follows the stack position")
    func stackOffFollowsPosition() throws {
        var context = makeContext()
        context.stack.fillWhenAlone = false
        context.stack.stackPosition = .left
        let alone = try #require(
            StackLayout().calculateGeometry(
                for: [w1],
                in: context
            )[w1]
        )
        #expect(alone.maxX == context.usable.maxX)
        #expect(abs(alone.width - 1890 * 0.6) < 0.01)
    }

    @Test("Stack off: two masters with no stack still fill")
    func stackOffTwoMastersFill() throws {
        // The toggle is about ONE window; a full master zone
        // with nothing stacked keeps the whole area.
        var context = makeContext()
        context.stack.fillWhenAlone = false
        context.stack.masterCount = 2
        let frames = StackLayout().calculateGeometry(
            for: [w1, w2],
            in: context
        )
        let a = try #require(frames[w1])
        let b = try #require(frames[w2])
        #expect(abs(a.width + b.width + 10 - 1900) < 0.01)
    }

    @Test("Stack off: a screen too small for two zones fills")
    func stackOffTinyScreenFills() {
        var context = makeContext(
            bounds: CGRect(x: 0, y: 0, width: 500, height: 400)
        )
        context.stack.fillWhenAlone = false
        let frames = StackLayout().calculateGeometry(
            for: [w1],
            in: context
        )
        #expect(frames[w1] == context.usable)
    }

    @Test("The Lua setters write both flags")
    @MainActor func setters() {
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "kiwidesk-fill-alone-\(UUID().uuidString)"
                )
        )
        #expect(
            core.execute(
                "scroll.set_fill_when_alone",
                args: [.bool(false)]
            ).isSuccess
        )
        #expect(
            core.execute(
                "stack.set_fill_when_alone",
                args: [.bool(false)]
            ).isSuccess
        )
        #expect(!core.tiler.settings.scrolling.fillWhenAlone)
        #expect(!core.tiler.settings.stack.fillWhenAlone)
        #expect(
            !core.execute(
                "scroll.set_fill_when_alone",
                args: [.string("yes")]
            ).isSuccess
        )
    }
}
