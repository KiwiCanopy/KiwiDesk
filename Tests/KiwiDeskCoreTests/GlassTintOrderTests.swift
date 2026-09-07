import AppKit
import Testing

@testable import KiwiDeskCore

/// **The tint backdrop stays beneath its glass across every
/// hosting arm** (#1314).
///
/// `GlassTint.apply` inserted the backdrop below the glass only
/// while it had no superview. The Space Bar's `spanBackdrop` arm
/// then MOVES the glass below the item container, and a sibling
/// move leaves the backdrop where it was — above the glass, an
/// opaque-ish colour over the material for the rest of the
/// process, since nothing re-ordered it. The clauses drive the
/// production render through `SpaceBarManager.sync` rather than
/// a hand-built hierarchy, so the arm that moves the glass is
/// the real one.
@Suite("Glass tint order (#1314)")
@MainActor
struct GlassTintOrderTests {
    private static let frame = CGRect(x: 0, y: 0, width: 80, height: 24)

    /// Below macOS 26 no glass is hosted, so the plate and the
    /// tint never exist and every clause would pass on nil.
    private static var drawsGlass: Bool {
        if #available(macOS 26, *) { return true }
        return false
    }

    /// The hug arm: three Spaces on the 1440 pt fixture strip.
    private static var hugged: SpaceBarManager.Bar {
        paintedSpaceBar(front: nil, spaces: 3, glass: true)
    }

    /// The span-backdrop arm: sixty Spaces overflow the strip
    /// (each auto-length slot is 28 pt plus a 6 pt gap, ~2034 pt
    /// against 1440), and the front-app segment, ~76 pt, still
    /// fits the pinned band. Those are defaults the fixture
    /// reasons from (tests.md ▸ #660), so the clause REQUIRES the
    /// arm rather than trusting the arithmetic.
    private static var spanned: SpaceBarManager.Bar {
        paintedSpaceBar(front: WindowID(1), spaces: 60, glass: true)
    }

    /// The tint's and the plate's indices in the panel content.
    private static func order(
        _ overlay: SpaceBarOverlay
    ) throws -> (tint: Int, plate: Int) {
        let content = try #require(overlay.panel?.contentView)
        let tint = try #require(overlay.glassTint)
        let plate = try #require(overlay.glassPlate)
        return (
            try #require(content.subviews.firstIndex(of: tint)),
            try #require(content.subviews.firstIndex(of: plate))
        )
    }

    @Test("The tint stays beneath the plate across the span-backdrop arm")
    func tintStaysBeneathAcrossArms() throws {
        try #require(Self.drawsGlass, "no glass below macOS 26")
        let manager = SpaceBarManager()
        manager.sync([Self.hugged])
        let overlay = try #require(
            manager.overlayForTesting(barTitleDisplay)
        )
        let plate = try #require(overlay.glassPlate)
        try #require(
            GlassPlate.holds(plate, try #require(overlay.glassRun)),
            "three Spaces did not take the hug arm"
        )
        let hugged = try Self.order(overlay)
        try #require(
            hugged.tint == hugged.plate - 1,
            "the hugged arm already misorders: \(hugged)"
        )
        manager.sync([Self.spanned])
        // Only the span-backdrop arm hosts the filler and moves the
        // plate beneath the item container; on either other arm
        // the order below holds on unfixed code too.
        try #require(
            GlassPlate.holds(plate, overlay.glassBackdropFiller),
            "sixty Spaces with a front app did not take span-backdrop"
        )
        let content = try #require(overlay.panel?.contentView)
        try #require(
            try #require(content.subviews.firstIndex(of: plate))
                < (try #require(
                    content.subviews.firstIndex(of: overlay.itemContainer)
                )),
            "the span-backdrop arm did not move the plate"
        )
        let spanned = try Self.order(overlay)
        #expect(
            spanned.tint == spanned.plate - 1,
            "span-backdrop leaves the tint above the plate: \(spanned)"
        )
        manager.sync([Self.hugged])
        try #require(
            GlassPlate.holds(plate, try #require(overlay.glassRun)),
            "the return to three Spaces did not take the hug arm"
        )
        let again = try Self.order(overlay)
        #expect(
            again.tint == again.plate - 1,
            "the tint stays above the plate after the arm: \(again)"
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
        let backdrop = NSView(frame: Self.frame)
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
        let backdrop = NSView(frame: Self.frame)
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

    private static func apply(_ backdrop: NSView, below glass: NSView) {
        GlassTint.apply(
            backdrop,
            below: glass,
            frame: frame,
            cornerRadius: 4,
            hex: "#14201CB3"
        )
    }
}
