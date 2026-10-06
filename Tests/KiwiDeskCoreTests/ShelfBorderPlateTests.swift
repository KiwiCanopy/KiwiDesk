import AppKit
import Testing

@testable import KiwiDeskCore

/// The border on the shelf's plate under Plain (#1679), built
/// through the real overlay: shown, above the plate and its
/// glass, kept under Reduce transparency, and gone under Boxed
/// or while the switch is off. The boxes are
/// `ShelfBorderDrawingTests`'.
@Suite("Shelf border drawing — plate")
@MainActor
struct ShelfBorderPlateTests {
    private static let width: CGFloat = 3
    private static let color = "#FF000080"

    /// The machine's Reduce transparency setting is a default this
    /// fixture reasons from, so it is pinned off (#660, #1374).
    init() { LiquidGlassGate.override = { false } }

    private static func bordered(
        _ shelf: KiwiShelf = KiwiShelf(),
        on: Bool = true
    ) -> KiwiShelf {
        var shelf = shelf
        shelf.border = on
        shelf.borderWidth = width
        shelf.borderColor = color
        return shelf
    }

    /// `view` strokes the shelf's border: shown, at the width, in
    /// the colour, on `bounds`-sized frame `frame`.
    private func expectStroke(
        _ view: NSView,
        frame: CGRect,
        _ comment: Comment? = nil
    ) {
        #expect(!view.isHidden, comment)
        #expect(view.layer?.borderWidth == Self.width, comment)
        #expect(
            view.layer?.borderColor
                == NSColor(kiwiHex: Self.color).cgColor,
            comment
        )
        #expect(view.layer?.backgroundColor == nil, comment)
        #expect(view.frame == frame, comment)
    }

    private static func boxed(glass: Bool) -> KiwiShelf {
        var shelf = KiwiShelf()
        shelf.backgroundStyle = .boxed
        shelf.liquidGlass = glass
        return shelf
    }

    private func plateOverlay(_ shelf: KiwiShelf) throws -> ShelfOverlay {
        let spaces = SpaceBarManager()
        spaces.sync([paintedSpaceBar(front: nil, spaces: 3)])
        let section = try #require(
            spaces.shownOverlay(on: barTitleDisplay)
        )
        let shelves = ShelfManager()
        shelves.sync([
            ShelfManager.Shelf(
                display: barTitleDisplay,
                edge: .top,
                strip: barTitleStrip,
                shelf: shelf,
                sheen: 0,
                space: section,
                app: nil
            )
        ])
        return try #require(shelves.overlayForTesting(barTitleDisplay))
    }

    @Test("The plate's border rims the plate, above it, below the strip")
    func plateStrokes() throws {
        var shelf = Self.bordered()
        shelf.liquidGlass = false
        let overlay = try plateOverlay(shelf)
        let plate = try #require(overlay.solidPlate)
        expectStroke(overlay.plateBorder, frame: plate.frame)
        #expect(
            overlay.plateBorder.layer?.cornerRadius
                == plate.layer?.cornerRadius
        )
        let order = overlay.content.subviews
        let rim = try #require(order.firstIndex(of: overlay.plateBorder))
        #expect(try #require(order.firstIndex(of: plate)) < rim)
        #expect(rim < (try #require(order.firstIndex(of: overlay.stripView))))
    }

    /// Under Liquid Glass the rim strokes over the glass plate, so
    /// the material never covers it.
    @Test("The plate's rim sits above the glass plate")
    func plateRimAboveGlass() throws {
        guard #available(macOS 26, *) else { return }
        var shelf = Self.bordered()
        shelf.liquidGlass = true
        let overlay = try plateOverlay(shelf)
        let glass = try #require(overlay.glassPlate)
        #expect(!glass.isHidden)
        expectStroke(overlay.plateBorder, frame: glass.frame)
        let order = overlay.content.subviews
        let rim = try #require(order.firstIndex(of: overlay.plateBorder))
        #expect(try #require(order.firstIndex(of: glass)) < rim)
    }

    /// Reduce transparency stands the glass down, never the rim:
    /// the border is not glass (#1374).
    @Test("Reduce transparency keeps the plate's rim")
    func reduceTransparencyKeepsTheRim() throws {
        LiquidGlassGate.override = { true }
        defer { LiquidGlassGate.override = { false } }
        var shelf = Self.bordered()
        shelf.liquidGlass = true
        let overlay = try plateOverlay(shelf)
        let plate = try #require(overlay.solidPlate)
        #expect(!plate.isHidden)
        expectStroke(overlay.plateBorder, frame: plate.frame)
    }

    /// A shelf that switches to Boxed hides the rim it drew under
    /// Plain — the same overlay, so its earlier rim is on screen.
    @Test("Switching to Boxed hides the plate's rim")
    func boxedHidesAnEarlierRim() throws {
        let spaces = SpaceBarManager()
        spaces.sync([paintedSpaceBar(front: nil, spaces: 3)])
        let section = try #require(
            spaces.shownOverlay(on: barTitleDisplay)
        )
        let shelves = ShelfManager()
        func sync(_ shelf: KiwiShelf) {
            shelves.sync([
                ShelfManager.Shelf(
                    display: barTitleDisplay,
                    edge: .top,
                    strip: barTitleStrip,
                    shelf: shelf,
                    sheen: 0,
                    space: section,
                    app: nil
                )
            ])
        }
        var plain = Self.bordered()
        plain.liquidGlass = false
        sync(plain)
        let overlay = try #require(shelves.overlayForTesting(barTitleDisplay))
        #expect(!overlay.plateBorder.isHidden)
        sync(Self.bordered(Self.boxed(glass: false)))
        #expect(overlay.plateBorder.isHidden)
    }

    @Test("No plate, or the border off, draws no plate rim")
    func noPlateRim() throws {
        var boxed = Self.bordered(Self.boxed(glass: false))
        boxed.backgroundFit = .hug
        #expect(try plateOverlay(boxed).plateBorder.isHidden)
        var off = Self.bordered(on: false)
        off.liquidGlass = false
        #expect(try plateOverlay(off).plateBorder.isHidden)
    }
}
