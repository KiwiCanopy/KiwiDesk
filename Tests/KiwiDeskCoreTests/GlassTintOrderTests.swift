import AppKit
import Testing

@testable import KiwiDeskCore

/// **The tint backdrop stays beneath its glass across every
/// hosting arm** (#1314).
///
/// `GlassTint.apply` inserted the backdrop below the glass only
/// while it had no superview, so a glass moved among its siblings
/// left the backdrop above it — an opaque-ish colour over the
/// material for the rest of the process. The glass is the
/// shelf's since #1517, and the shelf never moves it among its
/// siblings, so the first clause holds only the production ORDER
/// — tint beneath plate beneath the section strip, across arms —
/// and cannot see #1314's drift; the mechanism clauses below are
/// what hold the repair.
@Suite("Glass tint order (#1314)")
@MainActor
struct GlassTintOrderTests {
    /// The machine's Reduce transparency setting is a default this
    /// fixture reasons from, so it is pinned off (#660, #1374).
    init() { LiquidGlassGate.override = { false } }

    private static let frame = CGRect(x: 0, y: 0, width: 80, height: 24)

    /// Below macOS 26 no glass is hosted, so the plate and the
    /// tint never exist and every clause would pass on nil.
    private static var drawsGlass: Bool {
        if #available(macOS 26, *) { return true }
        return false
    }

    /// The tint's and the plate's indices in the shelf content.
    private static func order(
        _ overlay: ShelfOverlay
    ) throws -> (tint: Int, plate: Int) {
        let tint = try #require(overlay.glassTint)
        let plate = try #require(overlay.glassPlate)
        let content = overlay.content
        return (
            try #require(content.subviews.firstIndex(of: tint)),
            try #require(content.subviews.firstIndex(of: plate))
        )
    }

    /// One display's shelf over a Space Bar of `spaces`, glass on
    /// or off.
    private static func shelf(
        _ section: SpaceBarOverlay,
        glass: Bool
    ) -> ShelfManager.Shelf {
        var shelf = KiwiShelf()
        shelf.liquidGlass = glass
        return ShelfManager.Shelf(
            display: barTitleDisplay,
            strip: barTitleStrip,
            shelf: shelf,
            space: section,
            app: nil
        )
    }

    /// The shelf's one plate (#1517) moves between hosting a
    /// solid fill and glass, and a section re-renders on its own
    /// between shelf passes; the tint stays directly beneath the
    /// glass through all of it.
    @Test("The tint stays beneath the shelf's glass across arms")
    func tintStaysBeneathAcrossArms() throws {
        try #require(Self.drawsGlass, "no glass below macOS 26")
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
        let first = try Self.order(overlay)
        #expect(first.tint == first.plate - 1, "\(first)")
        // The plate sits beneath the strip that holds the sections.
        let strip = try #require(
            overlay.content.subviews.firstIndex(of: overlay.stripView)
        )
        #expect(first.plate < strip)
        shelves.sync([Self.shelf(section, glass: false)])
        shelves.sync([Self.shelf(section, glass: true)])
        spaces.sync([
            paintedSpaceBar(front: WindowID(1), spaces: 60, glass: true)
        ])
        let again = try Self.order(overlay)
        #expect(
            again.tint == again.plate - 1,
            "the tint left its glass after the arms: \(again)"
        )
    }

    /// The mechanism, one level down: a backdrop whose glass was
    /// moved beneath a sibling is re-ordered on the next apply.
    @Test("apply re-orders a backdrop that drifted above its glass")
    func applyReordersADriftedBackdrop() throws {
        try #require(Self.drawsGlass, "no glass below macOS 26")
        let parent = NSView(frame: Self.frame)
        let other = NSView(frame: Self.frame)
        let glass = NSView(frame: Self.frame)
        let backdrop = GlassBackdrop(frame: Self.frame)
        parent.addSubview(other)
        parent.addSubview(glass)
        Self.apply(backdrop, below: glass)
        try #require(parent.subviews.map { $0 } == [other, backdrop, glass])
        parent.addSubview(glass, positioned: .below, relativeTo: other)
        try #require(parent.subviews.map { $0 } == [glass, other, backdrop])
        Self.apply(backdrop, below: glass)
        #expect(
            parent.subviews.map { $0 } == [backdrop, glass, other],
            "apply left the order \(parent.subviews)"
        )
    }

    /// A parent that counts the backdrop being (re)inserted.
    /// AppKit fires no view-level callback when an already-hosted
    /// view is re-added, so only the parent can see a reparent.
    private final class Spy: NSView {
        var inserts = 0
        var watched: NSView?
        override func addSubview(
            _ view: NSView,
            positioned place: NSWindow.OrderingMode,
            relativeTo otherView: NSView?
        ) {
            if view === watched { inserts += 1 }
            super.addSubview(view, positioned: place, relativeTo: otherView)
        }
    }

    /// A backdrop already in place is not reparented — the
    /// re-order is a repair, not a per-render reparent, which is
    /// the churn #1315 names.
    @Test("A backdrop already beneath its glass is left alone")
    func settledBackdropIsNotReparented() throws {
        try #require(Self.drawsGlass, "no glass below macOS 26")
        let parent = Spy(frame: Self.frame)
        let glass = NSView(frame: Self.frame)
        let backdrop = GlassBackdrop(frame: Self.frame)
        parent.watched = backdrop
        parent.addSubview(glass)
        Self.apply(backdrop, below: glass)
        try #require(parent.inserts == 1, "the first apply inserts")
        Self.apply(backdrop, below: glass)
        Self.apply(backdrop, below: glass)
        #expect(
            parent.inserts == 1,
            "a settled backdrop was reparented \(parent.inserts - 1)x"
        )
    }

    private static func apply(
        _ backdrop: GlassBackdrop,
        below glass: NSView
    ) {
        GlassTint.apply(
            backdrop,
            below: glass,
            frame: frame,
            cornerRadius: 4,
            hex: "#14201CB3",
            edge: .top
        )
    }
}
