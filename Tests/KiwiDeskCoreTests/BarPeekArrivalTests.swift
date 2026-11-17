import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// **A section that joins its strip opens no peek the pointer did
/// not ask for** (#3388): a bar revealed under Off lands under the
/// resting pointer, and the placement's hover re-read then found an
/// item there and opened its peek, which stood until the pointer
/// crossed the item. Once the pointer moves, a reading opens one as
/// ever (#1946).
@Suite("Bar peek on an arriving section (#3388)", .serialized)
@MainActor
struct BarPeekArrivalTests {
    private let display = barTitleDisplay
    private let one = SpaceID("1")
    private let two = SpaceID("2")

    init() {
        LiquidGlassGate.override = { false }
        BarHoverHit.pointerOverride = { _ in BarHoverHit.offWindow }
    }

    /// Space 1 active on Notes (1); Space 2 holds Web (4).
    private func seededCore() -> KiwiCore {
        let core = makeBarCore()
        core.shelves.ordersPanels = true
        core.state.workspaces.assign(one, to: display)
        core.state.workspaces.assign(two, to: display)
        core.state.workspaces.activate(two)
        core.state.apply(
            .windowCreated(titledWindow(4, app: "Web", title: "Doc"))
        )
        core.state.workspaces.activate(one)
        core.state.apply(
            .windowCreated(titledWindow(1, app: "Notes", title: "Memo"))
        )
        core.state.apply(.windowFocused(WindowID(1)))
        return core
    }

    /// One render and placement, `updateBars`' order.
    private func render(_ core: KiwiCore) {
        var style = SpaceBarLook()
        style.liquidGlass = false
        let items = core.spaceBarItems(display: display, style: style)
        core.shelves.holdingRelayout {
            core.spaceBars.sync([
                SpaceBarManager.Bar(
                    display: display,
                    items: items,
                    strip: barTitleStrip,
                    style: style,
                    stateMarkColors: StateMarkColors(
                        sticky: "#ffffff",
                        floating: "#ffffff",
                        pocket: "#ffffff"
                    )
                )
            ])
        }
        core.shelves.sync([
            .init(
                display: display,
                edge: .top,
                strip: barTitleStrip,
                shelf: KiwiShelf(),
                sheen: 0,
                space: core.spaceBars.overlayForTesting(display),
                app: nil
            )
        ])
    }

    /// Rests the pointer on Space 2's Web glyph, wherever the bar
    /// draws it.
    private func restOnWeb(_ core: KiwiCore, nudge: CGFloat) {
        let display = display
        let two = two
        BarHoverHit.pointerOverride = { window in
            guard let overlay = core.spaceBars.overlayForTesting(display),
                let item = overlay.itemViews.first(where: {
                    $0.space == two
                }),
                let web = item.glyphTargets.first,
                web.window === window
            else { return BarHoverHit.offWindow }
            return web.convert(
                CGPoint(x: web.bounds.midX + nudge, y: web.bounds.midY),
                to: nil
            )
        }
    }

    private func close(_ core: KiwiCore) {
        core.shelves.peek.dismiss()
        core.shelves.peek.panel.panel?.orderOut(nil)
        BarHoverHit.pointerOverride = { _ in BarHoverHit.offWindow }
    }

    @Test("A bar arriving under the pointer opens no peek until it moves")
    func arrivalOpensNothing() throws {
        let core = seededCore()
        defer { close(core) }
        var dwells = 0
        core.shelves.peek.schedule = { _, _ in dwells += 1 }
        restOnWeb(core, nudge: 0)
        render(core)
        #expect(dwells == 0)
        // Placed again with the pointer where it rested: still none.
        render(core)
        #expect(dwells == 0)
        #expect(core.shelves.peek.pending == nil)
        // The pointer moves on the glyph: its peek opens as ever.
        restOnWeb(core, nudge: 1)
        let item = try #require(
            core.spaceBars.overlayForTesting(display)?.itemViews.first {
                $0.space == two
            }
        )
        item.syncHoverToPointer()
        #expect(dwells == 1)
        #expect(core.shelves.peek.pending != nil)
    }

    @Test("A section a show brings on screen is an arrival")
    func arrivalPredicate() {
        let strip = NSView()
        let placed = NSView()
        strip.addSubview(placed)
        let fresh = NSView()
        let sections = [placed, fresh].map {
            ShelfOverlay.Section(
                view: $0,
                slot: .zero,
                plate: .zero,
                content: .zero
            )
        }
        let arrived = { (shown: Bool, leaving: [NSView: UUID]) in
            ShelfOverlay.arrivals(
                sections,
                shownBefore: shown,
                on: strip,
                leaving: leaving
            )
        }
        // A shelf kept ordered out between reveals keeps its
        // sections on the strip: all arrive with its panel.
        #expect(arrived(false, [:]) == [placed, fresh])
        #expect(arrived(true, [:]) == [fresh])
        #expect(arrived(true, [placed: UUID()]) == [placed, fresh])
    }

    @Test("An arriving section's reading still closes a peek")
    func arrivalStillCloses() {
        let peek = BarPeek(menus: NotificationCenter())
        var dwells = 0
        peek.schedule = { _, _ in dwells += 1 }
        let window = NSPanel(
            contentRect: CGRect(x: 0, y: 0, width: 200, height: 40),
            styleMask: .borderless,
            backing: .buffered,
            defer: true
        )
        defer { window.orderOut(nil) }
        let root = AppBarOverlay.FlippedView()
        let item = AppBarOverlay.FlippedView()
        root.addSubview(item)
        window.contentView?.addSubview(root)
        var point = CGPoint(x: 10, y: 10)
        BarHoverHit.pointerOverride = { _ in point }
        let source = BarPeekSource.glyph([WindowID(4)])
        peek.arrive([root])
        peek.pointer(in: item, on: item, source: source, edge: .top)
        #expect(dwells == 0)
        point.x += 1
        peek.pointer(in: item, on: item, source: source, edge: .top)
        #expect(dwells == 1)
        #expect(peek.pending != nil)
        point.x += 1
        peek.arrive([root])
        peek.pointer(in: item, on: nil, source: nil, edge: .top)
        #expect(peek.pending == nil)
    }
}
