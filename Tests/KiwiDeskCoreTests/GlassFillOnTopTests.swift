import AppKit
import Testing

@testable import KiwiDeskCore

/// **The Fill draws on top of the glass material, beneath the
/// content** (#2569): the backdrop is the glass's `contentView`
/// and the content rides inside it, whichever of `setContent` and
/// `GlassTint.apply` comes first. Behind the glass, the key
/// window's denser material covered the colour (#2569 ▸ Ruling,
/// step 1 measured).
@Suite("Glass Fill on top (#2569)")
@MainActor
struct GlassFillOnTopTests {
    /// The machine's Reduce transparency setting is a default this
    /// fixture reasons from, so it is pinned off (#660, #1374).
    init() { LiquidGlassGate.override = { false } }

    private static let frame = CGRect(x: 0, y: 0, width: 80, height: 24)

    /// A glass sized to the fixture frame; nil below macOS 26,
    /// where no glass is hosted and every clause would pass on
    /// nil — each clause requires it.
    private static func glass() -> NSView? {
        let glass = GlassPlate.make()
        glass?.frame = frame
        return glass
    }

    private static func apply(
        _ backdrop: GlassBackdrop,
        in glass: NSView,
        hex: String = "#14201CB3"
    ) {
        GlassTint.apply(
            backdrop,
            in: glass,
            cornerRadius: 4,
            fill: GlassFill(hex: hex),
            edge: .top
        )
    }

    /// The glass's own content slot.
    private static func held(_ glass: NSView) -> NSView? {
        guard #available(macOS 26, *) else { return nil }
        return (glass as? NSGlassEffectView)?.contentView
    }

    @Test("A tint applied after the content wraps it")
    func applyWrapsHeldContent() throws {
        let glass = try #require(Self.glass(), "no glass below 26")
        let content = NSView()
        let backdrop = GlassBackdrop()
        GlassPlate.setContent(glass, content)
        Self.apply(backdrop, in: glass)
        #expect(Self.held(glass) === backdrop)
        #expect(content.superview === backdrop)
        #expect(GlassPlate.holds(glass, content))
        #expect(backdrop.frame == glass.bounds)
        #expect(content.frame == backdrop.bounds)
    }

    @Test("Content set after the tint lands inside it")
    func contentLandsInsideTheTint() throws {
        let glass = try #require(Self.glass(), "no glass below 26")
        let backdrop = GlassBackdrop()
        Self.apply(backdrop, in: glass)
        let first = NSView()
        let second = NSView()
        GlassPlate.setContent(glass, first)
        GlassPlate.setContent(glass, second)
        #expect(Self.held(glass) === backdrop)
        #expect(backdrop.subviews.map { $0 } == [second])
        #expect(first.superview == nil, "the displaced content stayed")
        #expect(GlassPlate.holds(glass, second))
        #expect(!GlassPlate.holds(glass, first))
    }

    /// A hand-back takes the content out of the tint and leaves
    /// the tint as the glass's content, for the next host.
    @Test("release looks through the tint")
    func releaseLooksThroughTheTint() throws {
        let glass = try #require(Self.glass(), "no glass below 26")
        let backdrop = GlassBackdrop()
        let content = NSView()
        GlassPlate.setContent(glass, content)
        Self.apply(backdrop, in: glass)
        #expect(GlassPlate.release(glass) === content)
        #expect(content.superview == nil)
        #expect(content.translatesAutoresizingMaskIntoConstraints)
        #expect(Self.held(glass) === backdrop)
        #expect(!GlassPlate.holds(glass, content))
        #expect(GlassPlate.release(glass) == nil)
    }

    /// The glass's resize writer carries the tint and what it
    /// holds (#2426): the gradient is the glass's bounds.
    @Test("update fits the tint and its content")
    func updateFitsBoth() throws {
        let glass = try #require(Self.glass(), "no glass below 26")
        let backdrop = GlassBackdrop()
        let content = NSView()
        GlassPlate.setContent(glass, content)
        Self.apply(backdrop, in: glass)
        let grown = CGRect(x: 0, y: 0, width: 200, height: 60)
        GlassPlate.update(glass, frame: grown, cornerRadius: 4)
        #expect(backdrop.frame == glass.bounds)
        #expect(content.frame == backdrop.bounds)
    }

    /// A clear Fill clears the gradient; the wrapper stays shown,
    /// since the content rides inside it.
    @Test("A clear Fill clears the gradient, not the wrapper")
    func clearFillKeepsTheWrapper() throws {
        let glass = try #require(Self.glass(), "no glass below 26")
        let backdrop = GlassBackdrop()
        let content = NSView()
        GlassPlate.setContent(glass, content)
        Self.apply(backdrop, in: glass)
        Self.apply(backdrop, in: glass, hex: "")
        #expect(!backdrop.isHidden)
        #expect(content.superview === backdrop)
        let colors = backdrop.gradient?.colors as? [CGColor] ?? []
        #expect(colors.allSatisfy { $0.alpha == 0 }, "\(colors)")
    }

    /// Repeated applies keep the one wrapper and its content: the
    /// re-wrap is a mint, never a per-render reparent (#1315).
    @Test("A settled tint is not re-wrapped")
    func settledTintStays() throws {
        let glass = try #require(Self.glass(), "no glass below 26")
        let backdrop = GlassBackdrop()
        let content = NSView()
        GlassPlate.setContent(glass, content)
        Self.apply(backdrop, in: glass)
        Self.apply(backdrop, in: glass)
        Self.apply(backdrop, in: glass)
        #expect(Self.held(glass) === backdrop)
        #expect(backdrop.subviews.map { $0 } == [content])
    }

    /// The shelf's plate hosts no view: its glass carries the tint
    /// alone, across a solid arm and a section re-render.
    @Test("The shelf's glass carries its tint across arms")
    func shelfGlassCarriesItsTint() throws {
        try #require(Self.glass() != nil, "no glass below 26")
        let spaces = SpaceBarManager()
        spaces.sync([paintedSpaceBar(front: nil, spaces: 3, glass: true)])
        let section = try #require(
            spaces.shownOverlay(on: barTitleDisplay)
        )
        let shelves = ShelfManager()
        shelves.sync([Self.shelf(section, glass: true)])
        let overlay = try #require(
            shelves.overlayForTesting(barTitleDisplay)
        )
        let plate = try #require(overlay.glassPlate)
        let tint = try #require(overlay.glassTint)
        #expect(Self.held(plate) === tint)
        #expect(tint.subviews.isEmpty, "\(tint.subviews)")
        shelves.sync([Self.shelf(section, glass: false)])
        shelves.sync([Self.shelf(section, glass: true)])
        spaces.sync([
            paintedSpaceBar(front: WindowID(1), spaces: 60, glass: true)
        ])
        #expect(Self.held(plate) === tint)
    }

    /// One display's shelf over a Space Bar, glass on or off.
    private static func shelf(
        _ section: SpaceBarOverlay,
        glass: Bool
    ) -> ShelfManager.Shelf {
        var shelf = KiwiShelf()
        shelf.liquidGlass = glass
        return ShelfManager.Shelf(
            display: barTitleDisplay,
            edge: .top,
            strip: barTitleStrip,
            shelf: shelf,
            sheen: 0,
            space: section,
            app: nil
        )
    }
}
