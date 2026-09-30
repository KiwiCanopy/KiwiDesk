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
        style: AppBarLook = AppBarLook()
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
            text: "Zed",
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

    /// The label draws `text` — the driver-resolved title.
    ///
    /// It cannot draw the app name instead, because the view is
    /// no longer told one: the write-only `name` that rode along
    /// for a future accessibility label was dropped rather than
    /// kept as scaffolding (#901 reintroduces it beside its
    /// consumer). What is left to assert is that the label draws
    /// the string it was handed — asserted directly, because a
    /// fixture sized to make truncation visible discriminates
    /// the MEASUREMENT or the DRAW but not both, and swapping
    /// this write was inert until it had its own assertion
    /// (guard-prover, 2026-08-19).
    @Test("The label draws the item's text")
    func labelDrawsText() {
        let view = makeView(thickness: 32, glyph: nil)
        view.configure(
            id: WindowID(1),
            text: "Downloads",
            icon: nil,
            glyph: nil,
            count: 1,
            active: false,
            horizontal: true,
            style: AppBarLook()
        )
        view.layout()
        #expect(view.label.stringValue == "Downloads")
    }

    /// The widest name defines the uniform slot — and must then
    /// FIT that slot untruncated (the center-alignment cell
    /// metric that tail-truncated exactly the longest tab).
    /// Parameterized over the formula's font branch: auto
    /// (`0`) and fixed.
    @Test(
        "The widest title fits the slot it defined",
        arguments: [CGFloat(0), CGFloat(18)]
    )
    func widestTitleFitsItsOwnSlot(fontSize: CGFloat) {
        let thickness: CGFloat = 32
        var style = AppBarLook()
        style.fontSize = fontSize
        let items = [
            // The widest TITLE deliberately belongs to the
            // app with the SHORTEST name. A measurement that
            // read `name` would size the slot to
            // "Systemeinstellungen" — narrower than the title
            // actually drawn below — and truncate it.
            AppBarOverlay.Item(
                id: WindowID(1),
                text: "Bedienungshilfen",
                icon: nil
            ),
            AppBarOverlay.Item(
                id: WindowID(2),
                text: "TanStack Start: Full-Stack React",
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
        // The item that DEFINED the width is the one that must
        // fit — item 2, whose title is the widest string in the
        // set above.
        view.configure(
            id: WindowID(2),
            text: "TanStack Start: Full-Stack React",
            icon: nil,
            glyph: ":settings:",
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

    /// A REUSED view that flips to a vertical bar hides its
    /// label — the case the horizontal fixtures cannot see.
    ///
    /// `AppBarOverlay` reconfigures surviving item views in
    /// place rather than rebuilding them, so a bar whose edge
    /// flips horizontal→vertical hands the same view a new
    /// `horizontal: false`. `layoutVertical` is then the only
    /// pass that runs, and it owns the hiding: nothing else on
    /// that path writes `label.isHidden`, so a view that drew a
    /// title keeps drawing it over the icons — with a stale
    /// string and a stale frame, and `layoutBadge` placing the
    /// group count beside the phantom name (review 2026-08-20,
    /// after a deletion this suite could not red).
    @Test("A view reused on a vertical bar hides its label")
    func verticalReuseHidesLabel() {
        let view = makeView(thickness: 32, glyph: nil)
        #expect(!view.label.isHidden, "fixture must start shown")
        view.configure(
            id: WindowID(1),
            text: "Downloads",
            icon: nil,
            glyph: nil,
            count: 1,
            active: false,
            horizontal: false,
            style: AppBarLook()
        )
        view.layout()
        #expect(view.label.isHidden)
    }
}
