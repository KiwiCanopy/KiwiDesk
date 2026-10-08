import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// A hovered Space Bar glyph takes the focused glyph's look, so a
/// click target reads as one (#1528, owner device pass
/// 2026-09-28); its siblings keep their dim tier. The hover is
/// read from the resting pointer through the shelf's own re-read
/// (#1665), so the fixture renders and places the bar the way
/// `updateBars` does.
@MainActor
private func makeCore() -> KiwiCore {
    let core = makeTestCore(
        configDirectory: FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwi-glyph-hover-\(UUID().uuidString)"
            )
    )
    // The hover re-read rides the shelf's relayout (#1665, #1894).
    core.shelves.ordersPanels = true
    return core
}

private func window(_ id: UInt32, app: String) -> ManagedWindow {
    ManagedWindow(
        id: WindowID(id),
        pid: 100,
        appName: app,
        title: "Doc",
        isFloating: false
    )
}

@Suite("Space bar glyph hover", .serialized)
@MainActor
struct SpaceBarGlyphHoverTests {
    private let display = barTitleDisplay

    init() {
        LiquidGlassGate.override = { false }
        BarHoverHit.pointerOverride = { _ in BarHoverHit.offWindow }
    }

    /// Space 1 active on Notes; Space 2 holds Web (4), Mail (5).
    private func seededCore() -> KiwiCore {
        let core = makeCore()
        core.state.workspaces.assign(SpaceID("1"), to: display)
        core.state.workspaces.assign(SpaceID("2"), to: display)
        core.state.workspaces.activate(SpaceID("2"))
        core.state.apply(.windowCreated(window(4, app: "Web")))
        core.state.apply(.windowCreated(window(5, app: "Mail")))
        core.state.workspaces.activate(SpaceID("1"))
        core.state.apply(.windowCreated(window(1, app: "Notes")))
        core.state.apply(.windowFocused(WindowID(1)))
        return core
    }

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
                        floating: "#ffffff"
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

    private func chip(_ core: KiwiCore) throws -> SpaceBarItemView {
        let overlay = try #require(
            core.spaceBars.overlayForTesting(display)
        )
        let item = try #require(
            overlay.itemViews.first { $0.space == SpaceID("2") }
        )
        try #require(item.window != nil)
        return item
    }

    private func centre(of view: NSView) -> CGPoint {
        view.convert(
            CGPoint(x: view.bounds.midX, y: view.bounds.midY),
            to: nil
        )
    }

    @Test("A hovered glyph is lit and its sibling keeps its tier")
    func hoveredGlyphIsLit() throws {
        defer {
            BarHoverHit.pointerOverride = { _ in BarHoverHit.offWindow }
        }
        let core = seededCore()
        render(core)
        let item = try chip(core)
        try #require(item.glyphTargets.count == 2)
        let web = item.glyphTargets[0]
        let onWeb = centre(of: web)
        BarHoverHit.pointerOverride = { _ in onWeb }
        render(core)
        #expect(item.hoveredTarget === web)
        #expect(item.isHovered)
        let dim = SpaceBarLook().dimFactor
        #expect(item.appViews[0].alphaValue == 1)
        #expect(abs(item.appViews[1].alphaValue - dim) < 0.001)
        // Off the glyphs but on the chip: the chip's own hover
        // lifts every glyph, as before.
        let onPad = CGPoint(
            x: item.convert(CGPoint.zero, to: nil).x + 2,
            y: centre(of: item).y
        )
        BarHoverHit.pointerOverride = { _ in onPad }
        render(core)
        #expect(item.hoveredTarget == nil)
        #expect(item.appViews.allSatisfy { $0.alphaValue == 1 })
    }

    @Test("An overflow row asks for its icon to be shown")
    func menuRowShowsItsIcon() throws {
        let menu = SpaceBarWindowMenu.make(
            [
                .init(
                    row: BarWindowRow(
                        window: WindowID(4),
                        pid: 1,
                        app: "Web",
                        title: "Doc",
                        icon: NSImage(size: NSSize(width: 32, height: 32))
                    ),
                    enabled: true
                )
            ],
            kind: .overflow
        ) { _ in }
        let item = menu.items[0]
        #expect(item.image?.size == NSSize(width: 16, height: 16))
        let key = "setPreferredImageVisibility:"
        guard item.responds(to: NSSelectorFromString(key)) else {
            return
        }
        #expect(
            item.value(forKey: "preferredImageVisibility") as? Int == 1
        )
    }
}
