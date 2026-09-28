import AppKit
import Testing

@testable import KiwiDeskCore

/// The sheen reaches every surface the one setting names (#1644) —
/// the bars' indicator, the shelf's border, the drag markers'
/// border — built through their real views, at the signed strength
/// either way; each surface clears its flat stroke or fill while
/// the ramp paints it, or a translucent colour would stack twice,
/// and a strength of 0 draws every one flat.
@Suite("Border sheen reaches every surface (#1644)")
@MainActor
struct BorderSheenSurfaceTests {
    init() { LiquidGlassGate.override = { false } }

    private func spaceItem(
        _ indicator: AppBarStyle.ActiveIndicator,
        sheen: CGFloat
    ) -> SpaceBarItemView {
        var look = SpaceBarLook()
        look.activeIndicator = indicator
        look.sheen = sheen
        look.border = true
        look.backgroundStyle = .boxed
        let view = SpaceBarItemView(
            frame: CGRect(x: 0, y: 0, width: 80, height: 40)
        )
        view.configure(
            identity: .space(SpaceID("1")),
            spaceGlyph: .text("1", tinted: true),
            apps: [],
            active: true,
            horizontal: true,
            style: look,
            stateMarkColors: StateMarkColors(
                sticky: "#ffffff",
                floating: "#ffffff"
            )
        )
        view.layout()
        return view
    }

    private func appItem(
        _ indicator: AppBarStyle.ActiveIndicator,
        sheen: CGFloat
    ) -> AppBarItemView {
        var look = AppBarLook()
        look.activeIndicator = indicator
        look.sheen = sheen
        let view = AppBarItemView(
            frame: NSRect(x: 0, y: 0, width: 120, height: 40)
        )
        view.configure(
            id: WindowID(1),
            text: "Zed",
            icon: nil,
            glyph: nil,
            count: 1,
            active: true,
            horizontal: true,
            style: look
        )
        view.layout()
        return view
    }

    private func isClear(_ color: CGColor?) -> Bool {
        (color?.alpha ?? 0) == 0
    }

    /// The indicator's flat ink — the outline's stroke, the edge
    /// mark's fill — draws nothing.
    private func flatInkIsClear(
        _ accent: NSView,
        _ indicator: AppBarStyle.ActiveIndicator
    ) -> Bool {
        guard let layer = accent.layer else { return false }
        switch indicator {
        case .outline:
            return isClear(layer.borderColor)
                && isClear(layer.backgroundColor)
        case .edgeMark:
            return layer.borderWidth == 0
                && isClear(layer.backgroundColor)
        }
    }

    @Test(
        "the Space Bar's indicator takes the ramp in place of its ink",
        arguments: [AppBarStyle.ActiveIndicator.outline, .edgeMark]
    )
    func spaceIndicator(_ indicator: AppBarStyle.ActiveIndicator) {
        let on = spaceItem(indicator, sheen: -0.5)
        #expect(on.accent.paint?.strength == -0.5)
        #expect(flatInkIsClear(on.accent, indicator))
        let off = spaceItem(indicator, sheen: 0)
        #expect(off.accent.paint == nil)
        let ink =
            indicator == .outline
            ? off.accent.layer?.borderColor
            : off.accent.layer?.backgroundColor
        #expect(!isClear(ink))
    }

    @Test(
        "the App Bar's indicator takes the ramp in place of its ink",
        arguments: [AppBarStyle.ActiveIndicator.outline, .edgeMark]
    )
    func appIndicator(_ indicator: AppBarStyle.ActiveIndicator) {
        let on = appItem(indicator, sheen: 0.5)
        #expect(on.accent.paint?.strength == 0.5)
        #expect(
            on.accent.paint?.width
                == (indicator == .outline
                    ? on.style.resolvedHighlightWidth : nil)
        )
        #expect(flatInkIsClear(on.accent, indicator))
        let off = appItem(indicator, sheen: 0)
        #expect(off.accent.paint == nil)
        #expect(!flatInkIsClear(off.accent, indicator))
    }

    @Test("the shelf's border takes the ramp in place of its stroke")
    func shelfBorder() {
        var shelf = KiwiShelf()
        shelf.border = true
        let view = ShelfBorder.make()
        view.frame = CGRect(x: 0, y: 0, width: 80, height: 30)
        ShelfBorder.paint(
            view,
            shelf: shelf,
            surface: .plate,
            cornerRadius: 6,
            sheen: -1
        )
        #expect(view.paint?.width == shelf.drawnBorderWidth)
        #expect(view.paint?.strength == -1)
        #expect(view.layer?.borderWidth == 0)
        ShelfBorder.paint(
            view,
            shelf: shelf,
            surface: .plate,
            cornerRadius: 6,
            sheen: 0
        )
        #expect(view.paint == nil)
        #expect(view.layer?.borderWidth == shelf.drawnBorderWidth)
    }

    @Test("the drag marker's border takes the ramp")
    func dragBorder() {
        let view = DragMarkerView(
            frame: CGRect(x: 0, y: 0, width: 80, height: 60)
        )
        let style = DragVisual.ghostDefault
        let stroke = WindowStroke(width: 5, cornerRadius: 8)
        view.render(style, stroke: stroke, glass: false, sheen: 0.5)
        #expect(view.rim.paint?.width == stroke.width)
        #expect(view.rim.paint?.strength == 0.5)
        #expect(view.layer?.borderWidth == 0)
        view.render(style, stroke: stroke, glass: false, sheen: 0)
        #expect(view.rim.paint == nil)
        #expect(view.layer?.borderWidth == stroke.width)
    }

    /// The Settings picture draws the sheen as the drag does: its
    /// own value, glass stood down or not.
    @Test("the drag preview draws the sheen under Reduce transparency")
    func dragPreview() {
        let before = LiquidGlassGate.override
        defer { LiquidGlassGate.override = before }
        let view = DragMarkerView(
            frame: CGRect(x: 0, y: 0, width: 80, height: 60)
        )
        LiquidGlassGate.override = { true }
        view.showPreview(
            .ghostDefault,
            stroke: WindowStroke(width: 5, cornerRadius: 8),
            storedGlass: true,
            sheen: 0.5
        )
        #expect(view.rim.paint != nil)
        view.showPreview(
            .ghostDefault,
            stroke: WindowStroke(width: 5, cornerRadius: 8),
            storedGlass: true,
            sheen: 0
        )
        #expect(view.rim.paint == nil)
    }
}
