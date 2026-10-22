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

    /// Every title draws in one slot as long as the title cap in
    /// the bar font's average glyph (#2545, owner ruling): the
    /// slot never reads the titles, a capped title of capitals —
    /// wider than lower-case — is cut by width, a short one sits
    /// inside by its ink, and the icon beside them never moves.
    /// Parameterized over the formula's font branch: auto (`0`)
    /// and fixed.
    @Test(
        "Every title draws in the cap's fixed slot",
        arguments: [CGFloat(0), CGFloat(18)]
    )
    func titlesDrawInTheFixedSlot(fontSize: CGFloat) throws {
        let thickness: CGFloat = 32
        var style = AppBarLook()
        style.fontSize = fontSize
        let width = { (texts: [String]) in
            AppBarOverlay.autoSlotWidth(
                items: texts.enumerated().map {
                    AppBarOverlay.Item(
                        id: WindowID(UInt32($0.offset + 1)),
                        text: $0.element,
                        icon: nil
                    )
                },
                style: style,
                horizontal: true,
                thickness: thickness
            )
        }
        let cap = style.resolvedTitleCap
        let lower = AppBarStyle.cappedTitle("space switch stalls", to: cap)
        let upper = AppBarStyle.cappedTitle("CLAUDE AGENT LANE", to: cap)
        // Two items each, so the run's end insets match.
        let slot = width([lower, "zsh"])
        #expect(width([upper, "zsh"]) == slot)
        #expect(width(["Mail", "TanStack Start: Full-Stack React"]) == slot)
        let titleSlot = AppBarOverlay.titleSlot(style, thickness: thickness)
        let drawn = { (text: String) -> AppBarItemView in
            let view = AppBarItemView(
                frame: NSRect(x: 0, y: 0, width: slot, height: thickness)
            )
            view.configure(
                id: WindowID(1),
                text: text,
                icon: nil,
                glyph: ":settings:",
                count: 1,
                active: false,
                horizontal: true,
                style: style
            )
            view.layout()
            return view
        }
        let views = [lower, upper, "Mail"].map(drawn)
        let icons = views.map(\.glyphLabel.frame)
        #expect(icons.allSatisfy { $0 == icons[0] })
        for view in views {
            let placed = view.horizontalPlacement(in: view.bounds.size)
            #expect(placed.text.width == titleSlot)
            let start = placed.x + placed.moon + placed.side + placed.spacing
            #expect(view.label.frame.minX >= start - 0.5)
            #expect(view.label.frame.maxX <= start + titleSlot + 0.5)
        }
        // Ten capitals pass the slot, so the label fills it and cuts.
        #expect(abs(views[1].label.frame.width - titleSlot) <= 0.5)
        #expect(!views[1].drawsTextInFull)
        // A short title's ink is centred on the slot.
        let short = views[2]
        let placed = short.horizontalPlacement(in: short.bounds.size)
        let mid =
            placed.x + placed.moon + placed.side + placed.spacing
            + titleSlot / 2
        let ink = BarTextGlyph.metrics(of: short.label).inkSpan(
            in: short.label.frame
        )
        #expect(abs((ink.lowerBound + ink.upperBound) / 2 - mid) <= 1)
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
