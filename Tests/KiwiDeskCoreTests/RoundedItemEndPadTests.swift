import AppKit
import Testing

@testable import KiwiDeskCore

/// A rounded item's ends pad the axis by what the corner cuts off
/// a square (#1763): `KiwiShelf.itemEndInset(forDepth:)` is the
/// one reading, and the length a bar measures is the extent its
/// items lay out, at every roundness.
@Suite("Rounded item ends pad the axis", .serialized)
@MainActor
struct RoundedItemEndPadTests {
    private static let depth: CGFloat = 40
    private static let strip = CGRect(
        x: 0,
        y: 0,
        width: 1440,
        height: depth
    )
    private static let roundnesses: [CGFloat] = [0, 50, 100]

    init() { LiquidGlassGate.override = { false } }

    private static func shelf(_ roundness: CGFloat) -> KiwiShelf {
        var shelf = KiwiShelf()
        shelf.cornerRoundness = roundness
        shelf.backgroundStyle = .boxed
        shelf.liquidGlass = false
        return shelf
    }

    private static func spaceLook(_ roundness: CGFloat) -> SpaceBarLook {
        var look = SpaceBarLook(
            shelf: shelf(roundness),
            bar: SpaceBarStyle(),
            sheen: 0
        )
        look.showFrontApp = true
        look.glyphGap = 0
        return look
    }

    private static func icon() -> NSImage {
        NSImage(size: NSSize(width: 64, height: 64), flipped: false) {
            NSColor.black.setFill()
            $0.fill()
            return true
        }
    }

    private static func app(_ name: String) -> SpaceBarItemView.App {
        SpaceBarItemView.App(
            name: name,
            icon: icon(),
            glyph: nil,
            focused: false,
            count: 1
        )
    }

    private static var items: [SpaceBarOverlay.Item] {
        [
            SpaceBarOverlay.Item(
                space: SpaceID("1"),
                spaceGlyph: .text("1", tinted: true),
                apps: ["Finder", "Mail", "Claude"].map { app($0) },
                active: true,
                overflow: [],
                focusInOverflow: false
            )
        ]
    }

    private func spaceBar(_ roundness: CGFloat) throws -> SpaceBarOverlay {
        let manager = SpaceBarManager()
        manager.sync([
            SpaceBarManager.Bar(
                display: barTitleDisplay,
                items: Self.items,
                frontApp: Self.app("Claude"),
                frontWindow: WindowID(1),
                strip: Self.strip,
                style: Self.spaceLook(roundness),
                stateMarkColors: StateMarkColors(
                    sticky: "#ffffff",
                    floating: "#ffffff"
                )
            )
        ])
        return try #require(manager.overlayForTesting(barTitleDisplay))
    }

    // MARK: - The one home

    @Test("The corner cut is r·(1 − 1/√2), and nothing unrounded")
    func cornerCut() {
        #expect(KiwiShelf.cornerCut(radius: 0) == 0)
        #expect(KiwiShelf.cornerCut(radius: -3) == 0)
        let cut = KiwiShelf.cornerCut(radius: 20)
        #expect(abs(cut - 20 * (1 - 1 / 2.0.squareRoot())) < 1e-9)
        // The distance a square's corner sits from the circle it
        // is inscribed in, along one axis.
        #expect(abs(cut - (20 - 20 / 2.0.squareRoot())) < 1e-9)
    }

    @Test("The end inset follows the item's corner radius")
    func endInsetFollowsRadius() {
        for roundness in Self.roundnesses {
            let shelf = Self.shelf(roundness)
            let radius = shelf.resolvedCornerRadius(forThickness: Self.depth)
            #expect(
                shelf.itemEndInset(forDepth: Self.depth)
                    == KiwiShelf.cornerCut(radius: radius)
            )
        }
        #expect(Self.shelf(0).itemEndInset(forDepth: Self.depth) == 0)
        let full = Self.shelf(100).itemEndInset(forDepth: Self.depth)
        #expect(full > 5.8 && full < 5.9)
    }

    // MARK: - The Space Bar

    @Test("A Space item's measured length is its laid-out extent")
    func spaceItemMeasuresWhatItDraws() throws {
        let pad = SpaceBarItemView.pad
        for roundness in Self.roundnesses {
            let look = Self.spaceLook(roundness)
            let inset = look.shelf.itemEndInset(forDepth: Self.depth)
            let overlay = try spaceBar(roundness)
            let view = try #require(overlay.itemViews.first)
            view.layoutSubtreeIfNeeded()
            let cell = view.cellLength
            // The measurement: the flat length plus the inset at
            // both ends, read independently of the render.
            let flat = pad * 2 + cell + (pad + 1 + pad) + 3 * cell
            #expect(view.frame.width == flat + 2 * inset)
            // The layout: the identifier cell starts one pad and
            // the inset in, the last glyph ends as far from the
            // trailing end.
            let first = try #require(view.appViews.first).frame
            let last = try #require(view.appViews.last).frame
            let leading = first.minX - (cell + pad + 1 + pad)
            #expect(abs(leading - (pad + inset)) <= 0.5)
            #expect(
                abs(view.bounds.width - last.maxX - (pad + inset))
                    <= 0.5,
                "roundness \(roundness)"
            )
        }
    }

    @Test("The Space run's need grows by the inset per item end")
    func spaceNeedCarriesTheInset() {
        let square = SpaceBarOverlay.naturalLength(
            items: Self.items,
            depth: Self.depth,
            look: Self.spaceLook(0)
        )
        for roundness in Self.roundnesses {
            let look = Self.spaceLook(roundness)
            let inset = look.shelf.itemEndInset(forDepth: Self.depth)
            #expect(
                SpaceBarOverlay.naturalLength(
                    items: Self.items,
                    depth: Self.depth,
                    look: look
                ) == square + 2 * inset * CGFloat(Self.items.count)
            )
        }
    }

    /// The owner's case: at roundness 100 the ends are semicircles
    /// and the last square cell's outer corners stay inside them.
    @Test("At full roundness the last glyph clears the rounded end")
    func lastGlyphClearsTheCurve() throws {
        let overlay = try spaceBar(100)
        let view = try #require(overlay.itemViews.first)
        view.layoutSubtreeIfNeeded()
        let radius = view.cornerRadius
        #expect(radius == Self.depth / 2)
        let last = try #require(view.appViews.last).frame
        let centre = CGPoint(
            x: view.bounds.width - radius,
            y: view.bounds.height / 2
        )
        for corner in [
            CGPoint(x: last.maxX, y: last.minY),
            CGPoint(x: last.maxX, y: last.maxY),
        ] {
            #expect(hypot(corner.x - centre.x, corner.y - centre.y) <= radius)
        }
    }

    @Test("The front-app chip pads its rounded ends")
    func frontChipPadsItsEnds() throws {
        for roundness in Self.roundnesses {
            let look = Self.spaceLook(roundness)
            let end =
                SpaceBarItemView.pad
                + look.shelf.itemEndInset(forDepth: Self.depth)
            let overlay = try spaceBar(roundness)
            #expect(!overlay.frontBox.isHidden)
            let box = overlay.frontBox.frame
            #expect(abs(overlay.frontIcon.frame.minX - box.minX - end) <= 0.5)
            #expect(abs(box.maxX - overlay.frontName.frame.maxX - end) <= 0.5)
            #expect(
                overlay.chipEndPad(look, depth: Self.depth) == end
            )
        }
    }

    // MARK: - The App Bar

    private static func appLook(_ roundness: CGFloat) -> AppBarLook {
        var look = AppBarLook()
        look.shelf = shelf(roundness)
        look.edge = .top
        look.content = .iconAndTitle
        return look
    }

    private func appItem(
        width: CGFloat,
        look: AppBarLook
    ) -> AppBarItemView {
        let view = AppBarItemView(
            frame: CGRect(x: 0, y: 0, width: width, height: Self.depth)
        )
        view.configure(
            id: WindowID(1),
            text: "Downloads",
            icon: Self.icon(),
            glyph: nil,
            count: 1,
            active: true,
            horizontal: true,
            style: look
        )
        view.layout()
        return view
    }

    @Test("An App Bar slot measures the end padding it lays out")
    func appSlotMeasuresWhatItDraws() {
        func slot(_ look: AppBarLook) -> CGFloat {
            AppBarOverlay.slot(
                items: [appBarItem(1, text: "Downloads")],
                style: look,
                thickness: Self.depth,
                capAxis: 2000
            )
        }
        let square = slot(Self.appLook(0))
        for roundness in Self.roundnesses {
            let look = Self.appLook(roundness)
            let inset = look.shelf.itemEndInset(forDepth: Self.depth)
            let end = AppBarItemView.endPadding(
                look.shelf,
                depth: Self.depth
            )
            #expect(end == AppBarItemView.edgePadding + inset)
            // The measurement grows by the inset at both ends, read
            // apart from the layout, which clamps to any width.
            let slot = slot(look)
            #expect(abs(slot - square - 2 * inset) < 1e-9)
            let view = appItem(width: slot, look: look)
            // Measured wide enough: the title is drawn whole.
            let title = ceil(view.label.cell?.cellSize.width ?? 0)
            #expect(view.label.frame.width >= title)
            #expect(abs(view.iconView.frame.minX - end) <= 0.5)
            #expect(
                abs(slot - view.label.frame.maxX - end) <= 0.5,
                "roundness \(roundness)"
            )
        }
    }

    /// A slot capped short of its title truncates the title at the
    /// end padding rather than into the rounded end.
    @Test("A capped App Bar slot keeps the end padding")
    func cappedAppSlotKeepsThePadding() {
        for roundness in Self.roundnesses {
            let look = Self.appLook(roundness)
            let end = AppBarItemView.endPadding(
                look.shelf,
                depth: Self.depth
            )
            let view = appItem(width: 96, look: look)
            #expect(!view.label.isHidden)
            #expect(abs(view.iconView.frame.minX - end) <= 0.5)
            #expect(
                abs(96 - view.label.frame.maxX - end) <= 0.5,
                "roundness \(roundness)"
            )
        }
    }
}
