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
            style: AppBarStyle()
        )
        view.layout()
        #expect(view.label.stringValue == "Downloads")
    }

    @Test("Name-only content shows neither glyph nor image")
    func nameOnlyHidesGlyph() {
        var style = AppBarStyle()
        style.content = .title
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
        "The widest title fits the slot it defined",
        arguments: [
            (AppBarStyle.Content.iconAndTitle, CGFloat(0)),
            (AppBarStyle.Content.iconAndTitle, CGFloat(18)),
            (AppBarStyle.Content.title, CGFloat(0)),
        ]
    )
    func widestTitleFitsItsOwnSlot(
        variant: (AppBarStyle.Content, CGFloat)
    ) {
        let thickness: CGFloat = 32
        var style = AppBarStyle()
        style.content = variant.0
        style.fontSize = variant.1
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
            glyph: variant.0 == .title ? nil : ":settings:",
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

    /// ...and an icon-only item hides its label outright.
    ///
    /// What it pins is the MEASUREMENT, which is the load-bearing
    /// half: `showText` zeroes `textSize`, and a zero-width label
    /// is hidden either way. Forcing `showText = true` reds this
    /// test and nothing in `AppBarSlotSizingTests` (mutation,
    /// 2026-08-20).
    ///
    /// It also settled a duplicate. `configure` hid the label as
    /// well, and the layout pass then decided it again, so
    /// mutating the `configure` write was inert in every suite —
    /// an unobservable write, now gone. `layoutHorizontal` owns
    /// this, through `Content.showsText` rather than a
    /// hand-spelled `== .icon`, so a later text-free case
    /// inherits the answer (review 2026-08-20).
    @Test("An icon-only item hides its label")
    func iconOnlyHidesLabel() {
        var style = AppBarStyle()
        style.content = .icon
        let view = makeView(
            thickness: 32,
            glyph: ":zed:",
            style: style
        )
        #expect(view.label.isHidden)
    }
}
