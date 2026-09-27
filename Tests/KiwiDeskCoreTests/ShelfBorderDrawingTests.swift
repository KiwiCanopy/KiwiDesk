import AppKit
import Testing

@testable import KiwiDeskCore

/// The border reaches every surface it rims (#1679), built
/// through the real views: the shelf's plate under Plain, each
/// item's box under Boxed on both bars, and the Space Bar's
/// front-app chip — and nothing while the switch is off.
@Suite("Shelf border drawing")
@MainActor
struct ShelfBorderDrawingTests {
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

    // MARK: - Boxes

    private func spaceItem(_ shelf: KiwiShelf) -> SpaceBarItemView {
        let view = SpaceBarItemView(
            frame: CGRect(x: 0, y: 0, width: 80, height: 40)
        )
        view.configure(
            identity: .space(SpaceID("1")),
            spaceGlyph: .text("1", tinted: true),
            apps: [],
            active: true,
            horizontal: true,
            style: SpaceBarLook(shelf: shelf),
            stateMarkColors: StateMarkColors(
                sticky: "#ffffff",
                floating: "#ffffff"
            )
        )
        view.layout()
        return view
    }

    private func appItem(_ shelf: KiwiShelf) -> AppBarItemView {
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
            style: AppBarLook(shelf: shelf)
        )
        view.layout()
        return view
    }

    private static func boxed(glass: Bool) -> KiwiShelf {
        var shelf = KiwiShelf()
        shelf.backgroundStyle = .boxed
        shelf.liquidGlass = glass
        return shelf
    }

    /// Solid boxes and glass ones alike: under glass the item
    /// view is the glass's content, so it carries the rim too.
    @Test("Both bars' boxes stroke the border", arguments: [false, true])
    func boxesStroke(glass: Bool) {
        let shelf = Self.bordered(Self.boxed(glass: glass))
        let space = spaceItem(shelf)
        expectStroke(space.boxBorder, frame: space.bounds, "space")
        #expect(space.boxBorder.layer?.cornerRadius == space.cornerRadius)
        let app = appItem(shelf)
        expectStroke(app.boxBorder, frame: app.bounds, "app")
        #expect(
            app.boxBorder.layer?.cornerRadius
                == app.style.resolvedCornerRadius(
                    forThickness: app.crossThickness
                )
        )
    }

    /// The active outline strokes OVER the border, never under it.
    @Test("A box's border sits beneath the active outline")
    func borderBeneathOutline() {
        let shelf = Self.bordered(Self.boxed(glass: false))
        let space = spaceItem(shelf)
        let app = appItem(shelf)
        for (view, border, clip) in [
            (space as NSView, space.boxBorder, space.accentClip),
            (app, app.boxBorder, app.accentClip),
        ] {
            let order = view.subviews
            let rim = order.firstIndex(of: border)
            let accent = order.firstIndex(of: clip)
            #expect(rim != nil && accent != nil && rim! < accent!)
        }
    }

    @Test("Plain items and a switched-off border draw no box rim")
    func noRimOffOrPlain() {
        var plain = Self.bordered()
        plain.backgroundStyle = .plain
        let off = Self.bordered(Self.boxed(glass: false), on: false)
        for shelf in [plain, off] {
            #expect(spaceItem(shelf).boxBorder.isHidden)
            #expect(appItem(shelf).boxBorder.isHidden)
        }
    }

    // MARK: - The front-app chip

    private func frontOverlay(
        _ shelf: KiwiShelf
    ) throws -> SpaceBarOverlay {
        let base = paintedSpaceBar(front: WindowID(1))
        var style = base.style
        style.shelf = shelf
        let bar = SpaceBarManager.Bar(
            display: base.display,
            items: base.items,
            frontApp: base.frontApp,
            frontWindow: base.frontWindow,
            strip: base.strip,
            style: style,
            stateMarkColors: base.stateMarkColors
        )
        let manager = SpaceBarManager()
        manager.sync([bar])
        return try #require(manager.overlayForTesting(barTitleDisplay))
    }

    @Test("The front-app chip strokes the border")
    func frontChipStrokes() throws {
        let overlay = try frontOverlay(
            Self.bordered(Self.boxed(glass: false))
        )
        expectStroke(overlay.frontBorder, frame: overlay.frontBox.frame)
        let off = try frontOverlay(
            Self.bordered(Self.boxed(glass: false), on: false)
        )
        #expect(off.frontBorder.isHidden)
    }

    /// Under box glass the chip's rim strokes ABOVE its glass, so
    /// the material never covers it.
    @Test("The front-app chip's rim sits above its glass")
    func frontChipRimAboveGlass() throws {
        guard #available(macOS 26, *) else { return }
        let overlay = try frontOverlay(
            Self.bordered(Self.boxed(glass: true))
        )
        let glass = try #require(overlay.frontGlass)
        #expect(!glass.isHidden)
        expectStroke(overlay.frontBorder, frame: glass.frame)
        let host = try #require(glass.superview)
        #expect(overlay.frontBorder.superview === host)
        let order = host.subviews
        let rim = try #require(order.firstIndex(of: overlay.frontBorder))
        #expect(try #require(order.firstIndex(of: glass)) < rim)
    }

    // MARK: - The plate

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
                strip: barTitleStrip,
                shelf: shelf,
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
                    strip: barTitleStrip,
                    shelf: shelf,
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
