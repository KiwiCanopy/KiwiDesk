import AppKit
import Testing

@testable import KiwiDeskCore

/// What the #1901 skip must still redraw for: a Reduce
/// transparency flip between two identical shows, a show during a
/// shelf's fade-out, and the icon cache that keeps the input
/// comparable — a nil it must not keep, an exit it must forget.
@Suite("Bar render environment (#1901)", .serialized)
@MainActor
struct BarRenderEnvironmentTests {
    init() { LiquidGlassGate.override = { false } }

    private static let strip = CGRect(x: 0, y: 0, width: 900, height: 28)

    @Test("A transparency flip redraws an unchanged Space Bar")
    func spaceBarRedrawsOnGlassFlip() {
        let overlay = SpaceBarOverlay()
        var renders = 0
        overlay.onRendered = { renders += 1 }
        var look = SpaceBarLook()
        look.liquidGlass = true
        let items = ["1", "2"].map {
            SpaceBarOverlay.Item(
                space: SpaceID($0),
                spaceGlyph: .text($0, tinted: true),
                apps: [],
                active: $0 == "1",
                after: .none
            )
        }
        func show() {
            overlay.show(
                items: items,
                strip: Self.strip,
                style: look,
                stateMarkColors: StateMarkColors(
                    sticky: "#ffffff",
                    floating: "#ffffff"
                )
            )
        }
        show()
        let first = renders
        LiquidGlassGate.override = { true }
        defer { LiquidGlassGate.override = { false } }
        show()
        #expect(renders > first)
    }

    @Test("A transparency flip redraws an unchanged App Bar")
    func appBarRedrawsOnGlassFlip() {
        let overlay = AppBarOverlay()
        var renders = 0
        overlay.onRendered = { renders += 1 }
        var look = AppBarLook()
        look.liquidGlass = true
        func show() {
            overlay.show(
                items: [appBarItem(1, text: "One")],
                activeIndex: 0,
                strip: Self.strip,
                style: look,
                capAxis: 2000
            )
        }
        show()
        let first = renders
        LiquidGlassGate.override = { true }
        defer { LiquidGlassGate.override = { false } }
        show()
        #expect(renders > first)
    }

    @Test("A show during the fade-out fades the shelf back")
    func showDuringFadeIsNotSkipped() {
        pinShelfGlide()
        let overlay = ShelfOverlay()
        var shelf = KiwiShelf()
        shelf.liquidGlass = false
        let section = ShelfOverlay.Section(
            view: NSView(),
            slot: Self.strip,
            plate: .zero,
            content: .zero
        )
        func show() {
            overlay.show(
                strip: Self.strip,
                edge: .top,
                shelf: shelf,
                sheen: 0,
                sections: [section]
            )
        }
        show()
        overlay.hide(animated: true)
        // Under Reduce Motion (CI's runner) a hide never fades, so
        // there is no fade-out to show into — `ShelfFadeTests`'
        // branch; the gate has no test override by bars.md's rule.
        guard !BarMotion.isReduced else {
            #expect(!overlay.isLeaving)
            return
        }
        #expect(overlay.isLeaving)
        show()
        #expect(!overlay.isLeaving)
    }

    @Test("A nil icon is read again; an exit forgets the icon")
    func iconCacheKeepsNoNilAndForgetsExits() {
        let pid: pid_t = 424_242
        var reads = 0
        var answer: NSImage? = nil
        let live = BarIconCache.read
        BarIconCache.read = { _ in
            reads += 1
            return answer
        }
        defer {
            BarIconCache.read = live
            BarIconCache.forget(pid: pid)
        }
        #expect(BarIconCache.icon(pid: pid) == nil)
        answer = NSImage(size: CGSize(width: 1, height: 1))
        #expect(BarIconCache.icon(pid: pid) === answer)
        #expect(BarIconCache.icon(pid: pid) === answer)
        #expect(reads == 2)
        // The exit arrives through the event flow.
        let core = makeTestCore()
        core.handle(.appTerminated(pid: pid))
        _ = BarIconCache.icon(pid: pid)
        #expect(reads == 3)
    }
}
