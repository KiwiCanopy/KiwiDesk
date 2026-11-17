import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// **A section that joins its strip opens no peek the pointer did
/// not ask for** (#3388): a bar revealed under Off lands under the
/// resting pointer, and the placement's hover re-read then found an
/// item there and opened its peek, which stood until the pointer
/// crossed the item. The re-read of a section already on the strip
/// still opens one, as a resting pointer's does (#1946).
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
    private func restOnWeb(_ core: KiwiCore) {
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
                CGPoint(x: web.bounds.midX, y: web.bounds.midY),
                to: nil
            )
        }
    }

    private func close(_ core: KiwiCore) {
        core.shelves.peek.dismiss()
        core.shelves.peek.panel.panel?.orderOut(nil)
        BarHoverHit.pointerOverride = { _ in BarHoverHit.offWindow }
    }

    @Test("A bar arriving under the pointer opens no peek")
    func arrivalOpensNothing() {
        let core = seededCore()
        defer { close(core) }
        var dwells = 0
        core.shelves.peek.schedule = { _, _ in dwells += 1 }
        restOnWeb(core)
        render(core)
        #expect(dwells == 0)
        #expect(core.shelves.peek.pending == nil)
        // Placed again, already on its strip: the resting pointer
        // opens the peek as ever.
        render(core)
        #expect(dwells == 1)
        #expect(core.shelves.peek.pending != nil)
    }

    @Test("An arriving section's reading still closes a peek")
    func arrivalStillCloses() {
        let peek = BarPeek(menus: NotificationCenter())
        var dwells = 0
        peek.schedule = { _, _ in dwells += 1 }
        let root = AppBarOverlay.FlippedView()
        let item = AppBarOverlay.FlippedView()
        root.addSubview(item)
        let source = BarPeekSource.glyph([WindowID(4)])
        peek.rereading(arrived: [root]) {
            peek.pointer(in: item, on: item, source: source, edge: .top)
        }
        #expect(dwells == 0)
        peek.pointer(in: item, on: item, source: source, edge: .top)
        #expect(dwells == 1)
        #expect(peek.pending != nil)
        peek.rereading(arrived: [root]) {
            peek.pointer(in: item, on: nil, source: nil, edge: .top)
        }
        #expect(peek.pending == nil)
    }
}
