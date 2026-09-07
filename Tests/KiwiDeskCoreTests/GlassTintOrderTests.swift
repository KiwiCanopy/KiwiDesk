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

    /// A plain + glass Space Bar with `spaces` Spaces. Sixty
    /// overflow the fixture strip (each slot is wider than 24 pt
    /// against 1440), and with the front-app segment on that is
    /// the `spanBackdrop` arm; three hug.
    private static func bar(
        spaces: Int,
        front: Bool
    ) -> SpaceBarManager.Bar {
        var style = SpaceBarStyle()
        style.backgroundStyle = .plain
        style.liquidGlass = true
        style.showFrontApp = front
        let items = (1...spaces).map { n in
            SpaceBarOverlay.Item(
                space: SpaceID(String(n)),
                spaceGlyph: .text(String(n), tinted: true),
                apps: [],
                active: n == 1,
                overflow: 0,
                focusInOverflow: false
            )
        }
        return SpaceBarManager.Bar(
            display: barTitleDisplay,
            items: items,
            frontApp: front
                ? SpaceBarItemView.App(
                    name: "Finder",
                    icon: nil,
                    glyph: nil,
                    focused: true,
                    count: 1
                ) : nil,
            frontWindow: front ? WindowID(1) : nil,
            strip: barTitleStrip,
            style: style,
            stateMarkColors: StateMarkColors(
                sticky: "#ffffff",
                floating: "#ffffff"
            )
        )
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
        manager.sync([Self.bar(spaces: 3, front: false)])
        let overlay = try #require(
            manager.overlayForTesting(barTitleDisplay)
        )
        let hugged = try Self.order(overlay)
        try #require(
            hugged.tint == hugged.plate - 1,
            "the hugged arm already misorders: \(hugged)"
        )
        manager.sync([Self.bar(spaces: 60, front: true)])
        let spanned = try Self.order(overlay)
        #expect(
            spanned.tint == spanned.plate - 1,
            "span-backdrop leaves the tint above the plate: \(spanned)"
        )
        manager.sync([Self.bar(spaces: 3, front: false)])
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

    /// Counts its own reparents.
    private final class Spy: NSView {
        var moves = 0
        override func viewWillMove(toSuperview newSuperview: NSView?) {
            if newSuperview != nil { moves += 1 }
        }
    }

    /// A backdrop already in place is not reparented — the
    /// re-order is a repair, not a per-render reparent, which is
    /// the churn #1315 names.
    @Test("A backdrop already beneath its glass is left alone")
    func settledBackdropIsNotReparented() throws {
        try #require(Self.drawsGlass, "no glass below macOS 26")
        let parent = NSView(frame: Self.frame)
        let glass = NSView(frame: Self.frame)
        let backdrop = Spy(frame: Self.frame)
        parent.addSubview(glass)
        Self.apply(backdrop, below: glass)
        try #require(backdrop.moves == 1, "the first apply inserts")
        Self.apply(backdrop, below: glass)
        Self.apply(backdrop, below: glass)
        #expect(
            backdrop.moves == 1,
            "a settled backdrop was reparented \(backdrop.moves - 1)x"
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
