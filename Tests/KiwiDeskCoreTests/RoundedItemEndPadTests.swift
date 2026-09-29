import AppKit
import Testing

@testable import KiwiDeskCore

/// A rounded item's ends pad the axis by the exact clearance its
/// content square needs (#1763): `KiwiShelf.endClearance` is the
/// one formula, `KiwiShelf.roundsItemEnds` the one predicate for
/// which ends are drawn rounded, and a Space item measures the
/// extent it lays out at every roundness and thickness.
@Suite("Rounded item ends pad the axis", .serialized)
@MainActor
struct RoundedItemEndPadTests {
    static let depth: CGFloat = 40
    static let roundnesses: [CGFloat] = [0, 50, 100]

    init() { LiquidGlassGate.override = { false } }

    static func strip(depth: CGFloat = depth) -> CGRect {
        CGRect(x: 0, y: 0, width: 1440, height: depth)
    }

    static func shelf(
        _ roundness: CGFloat,
        boxed: Bool = true
    ) -> KiwiShelf {
        var shelf = KiwiShelf()
        shelf.cornerRoundness = roundness
        shelf.backgroundStyle = boxed ? .boxed : .plain
        shelf.liquidGlass = false
        return shelf
    }

    /// The edge mark by default: the plate cases read the run's
    /// ends, which an outline widens to every item (#1763).
    static func spaceLook(
        _ roundness: CGFloat,
        boxed: Bool = true,
        outlined: Bool = false
    ) -> SpaceBarLook {
        var bar = SpaceBarStyle()
        bar.activeIndicator = outlined ? .outline : .edgeMark
        var look = SpaceBarLook(
            shelf: shelf(roundness, boxed: boxed),
            bar: bar,
            sheen: 0
        )
        look.showFrontApp = true
        look.glyphGap = 0
        return look
    }

    static func icon() -> NSImage {
        NSImage(size: NSSize(width: 64, height: 64), flipped: false) {
            NSColor.black.setFill()
            $0.fill()
            return true
        }
    }

    static func app(_ name: String) -> SpaceBarItemView.App {
        SpaceBarItemView.App(
            name: name,
            icon: icon(),
            glyph: nil,
            focused: false,
            count: 1
        )
    }

    /// A symbol identifier by default: icon-like at both ends, the
    /// case the clearance exists for; a number leads with none.
    static func items(
        _ count: Int,
        numbered: Bool = false
    ) -> [SpaceBarOverlay.Item] {
        (1...count).map { index in
            SpaceBarOverlay.Item(
                space: SpaceID("\(index)"),
                spaceGlyph: numbered
                    ? .text("\(index)", tinted: true)
                    : .symbol("envelope"),
                apps: ["Finder", "Mail", "Claude"].map { app($0) },
                active: index == 1,
                after: .none
            )
        }
    }

    static func spaceBar(
        _ look: SpaceBarLook,
        items: [SpaceBarOverlay.Item],
        depth: CGFloat = depth,
        front: SpaceBarItemView.App? = nil,
        width: CGFloat = 1440
    ) throws -> SpaceBarOverlay {
        let manager = SpaceBarManager()
        manager.sync([
            SpaceBarManager.Bar(
                display: barTitleDisplay,
                items: items,
                frontApp: front,
                frontWindow: front == nil ? nil : WindowID(1),
                strip: CGRect(x: 0, y: 0, width: width, height: depth),
                style: look,
                stateMarkColors: StateMarkColors(
                    sticky: "#ffffff",
                    floating: "#ffffff"
                )
            )
        ])
        let overlay = try #require(
            manager.overlayForTesting(barTitleDisplay)
        )
        overlay.itemViews.forEach { $0.layoutSubtreeIfNeeded() }
        return overlay
    }

    /// The Space cell's clearance, from the geometry alone.
    static func clearance(_ look: SpaceBarLook, depth: CGFloat) -> CGFloat {
        let cell = max(
            look.contentDepth(forDepth: depth) - 2 * SpaceBarItemView.pad,
            8
        )
        return KiwiShelf.endClearance(
            radius: look.resolvedCornerRadius(forThickness: depth),
            crossOffset: (depth - cell) / 2
        )
    }

    // MARK: - The one formula and the one predicate

    @Test("The clearance puts the content corner on the arc")
    func clearanceMeetsTheArc() {
        #expect(KiwiShelf.endClearance(radius: 0, crossOffset: 4) == 0)
        // A square starting past the radius never meets the curve.
        #expect(KiwiShelf.endClearance(radius: 10, crossOffset: 10) == 0)
        #expect(KiwiShelf.endClearance(radius: 10, crossOffset: 12) == 0)
        for (r, y) in [(20.0, 4.0), (40.0, 4.0), (14.0, 6.0), (10.0, 1.0)] {
            let e = KiwiShelf.endClearance(radius: r, crossOffset: y)
            #expect(e > 0 && e < r)
            // The corner (e, y) lies on the circle of the end.
            #expect(abs(hypot(r - e, r - y) - r) < 1e-9)
        }
    }

    /// The case r·(1 − 1/√2) failed: a thick fully rounded bar.
    @Test("At 80 pt and full roundness the clearance exceeds the cut")
    func thickBarNeedsMoreThanTheCut() {
        let e = KiwiShelf.endClearance(radius: 40, crossOffset: 4)
        #expect(abs(e - (40 - 304.0.squareRoot())) < 1e-9)
        #expect(e > KiwiShelf.cornerCut(radius: 40) + 10)
    }

    @Test("Boxed or outlined rounds every item's ends, a plate the run's")
    func roundedEndsPredicate() {
        let boxed = Self.shelf(100)
        let plate = Self.shelf(100, boxed: false)
        for first in [false, true] {
            for last in [false, true] {
                for outlined in [false, true] {
                    let b = boxed.roundsItemEnds(
                        first: first,
                        last: last,
                        outlined: outlined
                    )
                    #expect(b.leading && b.trailing)
                }
                let o = plate.roundsItemEnds(
                    first: first,
                    last: last,
                    outlined: true
                )
                #expect(o.leading && o.trailing)
                let p = plate.roundsItemEnds(
                    first: first,
                    last: last,
                    outlined: false
                )
                #expect(p.leading == first && p.trailing == last)
            }
        }
    }

    // MARK: - The Space Bar

    @Test("A boxed Space item measures the extent it lays out")
    func boxedItemMeasuresWhatItDraws() throws {
        let pad = SpaceBarItemView.pad
        for depth in [Self.depth, 80] {
            for roundness in Self.roundnesses {
                let look = Self.spaceLook(roundness)
                let e = Self.clearance(look, depth: depth)
                let overlay = try Self.spaceBar(
                    look,
                    items: Self.items(1),
                    depth: depth
                )
                let view = try #require(overlay.itemViews.first)
                let cell = view.cellLength
                let flat = pad * 2 + cell + (pad + 1 + pad) + 3 * cell
                #expect(view.frame.width == flat + 2 * e)
                let first = try #require(view.appViews.first).frame
                let last = try #require(view.appViews.last).frame
                let leading = first.minX - (cell + pad + 1 + pad)
                let trailing = view.bounds.width - last.maxX
                #expect(abs(leading - (pad + e)) <= 0.5)
                #expect(
                    abs(trailing - (pad + e)) <= 0.5,
                    "depth \(depth), roundness \(roundness)"
                )
            }
        }
    }

    /// Where r·(1 − 1/√2) left the corner outside the end.
    @Test("At 80 pt and full roundness every glyph clears the ends")
    func thickBarGlyphsClearTheCurve() throws {
        let depth: CGFloat = 80
        let overlay = try Self.spaceBar(
            Self.spaceLook(100),
            items: Self.items(1),
            depth: depth
        )
        let view = try #require(overlay.itemViews.first)
        let radius = view.cornerRadius
        #expect(radius == depth / 2)
        let identifier = view.cellRect(
            at: view.appViews[0].frame.minX
                - (view.cellLength + 2 * SpaceBarItemView.pad + 1),
            cell: view.cellLength
        )
        let last = try #require(view.appViews.last).frame
        let leadCentre = CGPoint(x: radius, y: depth / 2)
        let trailCentre = CGPoint(
            x: view.bounds.width - radius,
            y: depth / 2
        )
        for (centre, x) in [
            (leadCentre, identifier.minX), (trailCentre, last.maxX),
        ] {
            for y in [last.minY, last.maxY] {
                #expect(hypot(x - centre.x, y - centre.y) <= radius + 0.5)
            }
        }
    }

    @Test("On a plate only the run's outer ends take the clearance")
    func plateItemsPadOnlyTheRunEnds() throws {
        let pad = SpaceBarItemView.pad
        let look = Self.spaceLook(100, boxed: false)
        let e = Self.clearance(look, depth: Self.depth)
        #expect(e > 0)
        let overlay = try Self.spaceBar(look, items: Self.items(3))
        let views = Array(overlay.itemViews.prefix(3))
        let expected: [ItemEnds] = [
            ItemEnds(leading: e, trailing: 0),
            .zero,
            ItemEnds(leading: 0, trailing: e),
        ]
        for (view, ends) in zip(views, expected) {
            #expect(view.ends == ends)
            let cell = view.cellLength
            let flat = pad * 2 + cell + (pad + 1 + pad) + 3 * cell
            #expect(view.frame.width == flat + ends.total)
            let first = try #require(view.appViews.first).frame
            let last = try #require(view.appViews.last).frame
            let leading = first.minX - (cell + pad + 1 + pad)
            #expect(abs(leading - (pad + ends.leading)) <= 0.5)
            #expect(
                abs(view.bounds.width - last.maxX - (pad + ends.trailing))
                    <= 0.5
            )
        }
    }

    /// The front-app segment ends the run, so on a plate the last
    /// Space item draws no rounded trailing end and measures none.
    @Test("On a plate a following front app takes the run's end")
    func frontAppTakesThePlateRunEnd() throws {
        let pad = SpaceBarItemView.pad
        let look = Self.spaceLook(100, boxed: false)
        let e = Self.clearance(look, depth: Self.depth)
        let overlay = try Self.spaceBar(
            look,
            items: Self.items(1),
            front: Self.app("Claude")
        )
        let view = try #require(overlay.itemViews.first)
        #expect(view.ends == ItemEnds(leading: e, trailing: 0))
        let cell = view.cellLength
        let flat = pad * 2 + cell + (pad + 1 + pad) + 3 * cell
        #expect(view.frame.width == flat + e)
        let last = try #require(view.appViews.last).frame
        #expect(abs(view.bounds.width - last.maxX - pad) <= 0.5)
    }

    @Test("The run's need carries the clearance its items lay out")
    func needCarriesTheClearance() {
        let items = Self.items(3)
        for boxed in [true, false] {
            let square = SpaceBarOverlay.naturalLength(
                items: items,
                depth: Self.depth,
                look: Self.spaceLook(0, boxed: boxed)
            )
            for roundness in Self.roundnesses {
                let look = Self.spaceLook(roundness, boxed: boxed)
                let e = Self.clearance(look, depth: Self.depth)
                // Boxed: both ends of each item; a plate: the run's two.
                let ends = boxed ? 2 * CGFloat(items.count) : 2
                #expect(
                    SpaceBarOverlay.naturalLength(
                        items: items,
                        depth: Self.depth,
                        look: look
                    ) == square + ends * e
                )
            }
        }
    }
}
