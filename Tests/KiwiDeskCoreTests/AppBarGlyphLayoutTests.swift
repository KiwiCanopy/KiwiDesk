import AppKit
import Testing

@testable import KiwiDeskCore

/// Glyph occupancy of the item's icon slot (#294): the ligature
/// label replaces the image view, sizes to its cell, and stays
/// centered in the icon square at every supported thickness.
@Suite("App bar glyph slot layout")
@MainActor
struct AppBarGlyphLayoutTests {
    private func makeView(
        thickness: CGFloat,
        glyph: String?,
        style: AppBarStyle = AppBarStyle()
    ) -> AppBarItemView {
        let view = AppBarItemView(
            frame: NSRect(
                x: 0,
                y: 0,
                width: 120,
                height: thickness
            )
        )
        view.configure(
            id: WindowID(1),
            name: "Zed",
            icon: nil,
            glyph: glyph,
            count: 1,
            active: false,
            horizontal: true,
            style: style
        )
        view.layout()
        return view
    }

    @Test(
        "Glyph centers in the icon square at any thickness",
        arguments: [20.0, 32.0, 64.0]
    )
    func glyphCentered(thickness: CGFloat) {
        let view = makeView(thickness: thickness, glyph: ":zed:")
        #expect(!view.glyphLabel.isHidden)
        #expect(view.iconView.isHidden)
        let frame = view.glyphLabel.frame
        #expect(frame.height <= thickness)
        #expect(abs(frame.midY - thickness / 2) < 1)
    }

    @Test("No glyph falls back to the image path")
    func imageFallback() {
        let view = makeView(thickness: 32, glyph: nil)
        #expect(view.glyphLabel.isHidden)
    }

    @Test("Name-only content shows neither glyph nor image")
    func nameOnlyHidesGlyph() {
        var style = AppBarStyle()
        style.content = .name
        let view = makeView(
            thickness: 32,
            glyph: ":zed:",
            style: style
        )
        #expect(view.glyphLabel.isHidden)
        #expect(view.iconView.isHidden)
    }

    /// The widest name defines the uniform slot — and must then
    /// FIT that slot untruncated (the center-alignment cell
    /// metric that tail-truncated exactly the longest tab).
    /// Parameterized over the formula's branches: content mode
    /// (icon side present or not) and fixed-vs-auto font.
    @Test(
        "The widest name fits the slot it defined",
        arguments: [
            (AppBarStyle.Content.iconAndName, CGFloat(0)),
            (AppBarStyle.Content.iconAndName, CGFloat(18)),
            (AppBarStyle.Content.name, CGFloat(0)),
        ]
    )
    func widestNameFitsItsOwnSlot(
        variant: (AppBarStyle.Content, CGFloat)
    ) {
        let thickness: CGFloat = 32
        var style = AppBarStyle()
        style.content = variant.0
        style.fontSize = variant.1
        let items = [
            AppBarOverlay.Item(
                id: WindowID(1),
                name: "Systemeinstellungen",
                icon: nil
            ),
            AppBarOverlay.Item(
                id: WindowID(2),
                name: "Zen",
                icon: nil
            ),
        ]
        let slot = AppBarOverlay.autoSlotWidth(
            items: items,
            style: style,
            horizontal: true,
            thickness: thickness
        )
        let view = AppBarItemView(
            frame: NSRect(
                x: 0,
                y: 0,
                width: slot,
                height: thickness
            )
        )
        view.configure(
            id: WindowID(1),
            name: "Systemeinstellungen",
            icon: nil,
            glyph: variant.0 == .name ? nil : ":settings:",
            count: 1,
            active: false,
            horizontal: true,
            style: style
        )
        view.layout()
        // The label must have been given its full cell width —
        // a clamped width is what renders the "…" tail.
        #expect(!view.label.isHidden)
        let needed = ceil(view.label.cell?.cellSize.width ?? 0)
        #expect(view.label.frame.width >= needed)
    }
}
