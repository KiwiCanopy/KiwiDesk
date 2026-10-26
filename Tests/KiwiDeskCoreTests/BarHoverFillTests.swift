import AppKit
import Testing

@testable import KiwiDeskCore

/// A bar item's hover fades with the Fill on glass (#2645): both
/// bars paint it through `GlassTint.applyHover`, capped and faded by
/// the shelf's `fill_fade`, and keep the flat hover where no glass
/// draws.
@Suite("Bar hover fill on glass (#2645)", .serialized)
@MainActor
struct BarHoverFillTests {
    init() { LiquidGlassGate.override = { false } }

    private static func shelf(
        glass: Bool,
        hover: String = "#FFFFFF80",
        fade: CGFloat = 100
    ) -> KiwiShelf {
        var shelf = KiwiShelf()
        shelf.liquidGlass = glass
        // A Fill whose alpha differs from the hover's, so a hover
        // painted with the Fill reads apart.
        shelf.fillColor = "#14201CB3"
        shelf.hoverFillColor = hover
        shelf.fillFade = fade
        return shelf
    }

    private func appItem(_ shelf: KiwiShelf, hovered: Bool) -> AppBarItemView {
        let view = AppBarItemView(
            frame: NSRect(x: 0, y: 0, width: 150, height: 32)
        )
        var look = AppBarLook()
        look.shelf = shelf
        view.configure(
            id: WindowID(1),
            text: "Mail",
            icon: nil,
            glyph: nil,
            count: 1,
            active: false,
            horizontal: true,
            style: look
        )
        view.isHovered = hovered
        view.layout()
        view.applyColors()
        return view
    }

    private func spaceItem(
        _ shelf: KiwiShelf,
        hovered: Bool,
        dragHovered: Bool = false,
        active: Bool = false
    ) -> SpaceBarItemView {
        let view = SpaceBarItemView(
            frame: NSRect(x: 0, y: 0, width: 60, height: 32)
        )
        view.configure(
            identity: .space(SpaceID("2")),
            spaceGlyph: .text("2", tinted: false),
            apps: [],
            active: active,
            horizontal: true,
            style: SpaceBarLook(shelf: shelf, bar: SpaceBarStyle(), sheen: 0),
            stateMarkColors: StateMarkColors(sticky: "", floating: "")
        )
        view.isHovered = hovered
        view.isDragHovered = dragHovered
        view.layout()
        view.restyle()
        return view
    }

    /// The two ends' alphas the hover backdrop paints.
    private func ends(_ backdrop: GlassBackdrop) throws -> [CGFloat] {
        let colours = try #require(backdrop.gradient?.colors)
        return colours.map {
            NSColor(cgColor: $0 as! CGColor)?.alphaComponent ?? -1
        }
    }

    private func layerAlpha(_ view: NSView) -> CGFloat {
        view.layer?.backgroundColor?.alpha ?? 0
    }

    @Test("On glass the hover fades with the Fill, on both bars")
    func glassHoverFades() throws {
        let shelf = Self.shelf(glass: true)
        let far = GlassTint.farShare(fade: 100)
        for (view, backdrop) in [
            {
                let v = appItem(shelf, hovered: true)
                return (v as NSView, v.hoverFill)
            }(),
            {
                let v = spaceItem(shelf, hovered: true)
                return (v as NSView, v.hoverFill)
            }(),
        ] {
            #expect(!backdrop.isHidden)
            #expect(layerAlpha(view) == 0)
            let alphas = try ends(backdrop)
            #expect(alphas.count == 2)
            #expect(abs(alphas[0] - 0.5) < 0.01)
            #expect(abs(alphas[1] - 0.5 * far) < 0.01)
        }
    }

    @Test("The hover takes the glass cap and the shelf's fade")
    func hoverTakesTheCapAndFade() throws {
        let capped = appItem(
            Self.shelf(glass: true, hover: "#FFFFFFFF", fade: 0),
            hovered: true
        )
        let alphas = try ends(capped.hoverFill)
        #expect(abs(alphas[0] - GlassTint.maxAlpha) < 0.01)
        // Fade 0: the far end keeps the anchor.
        #expect(abs(alphas[1] - alphas[0]) < 0.01)
    }

    @Test("A solid shelf, an unhovered item or no glass keep it flat")
    func flatWhereNoGlassHovers() {
        let solid = appItem(Self.shelf(glass: false), hovered: true)
        #expect(solid.hoverFill.isHidden)
        #expect(abs(layerAlpha(solid) - 0.5) < 0.01)
        let solidSpace = spaceItem(Self.shelf(glass: false), hovered: true)
        #expect(solidSpace.hoverFill.isHidden)
        #expect(abs(layerAlpha(solidSpace) - 0.5) < 0.01)
        let resting = appItem(Self.shelf(glass: true), hovered: false)
        #expect(resting.hoverFill.isHidden)
        // Reduce transparency: no glass draws, so the hover is flat.
        LiquidGlassGate.override = { true }
        defer { LiquidGlassGate.override = { false } }
        let reduced = appItem(Self.shelf(glass: true), hovered: true)
        #expect(reduced.hoverFill.isHidden)
        #expect(abs(layerAlpha(reduced) - 0.5) < 0.01)
    }

    /// The Space Bar reads its one `showsHover`: a drag hover shows
    /// the glass hover, the current Space never does.
    @Test("A drag hover shows it; the current Space never does")
    func spaceHoverFollowsShowsHover() {
        let shelf = Self.shelf(glass: true)
        let dragged = spaceItem(shelf, hovered: false, dragHovered: true)
        #expect(!dragged.hoverFill.isHidden)
        let current = spaceItem(shelf, hovered: true, active: true)
        #expect(current.hoverFill.isHidden)
    }

    /// The box border draws over the hover on an item no glass
    /// hosts, as it does hosted (#2595).
    @Test("The hover sits below the box border")
    func hoverSitsBelowTheBorder() throws {
        let app = appItem(Self.shelf(glass: true), hovered: true)
        let space = spaceItem(Self.shelf(glass: true), hovered: true)
        for (order, hover, rim) in [
            (app.subviews, app.hoverFill as NSView, app.boxBorder as NSView),
            (space.subviews, space.hoverFill, space.boxBorder),
        ] {
            let below = try #require(order.firstIndex(of: hover))
            let above = try #require(order.firstIndex(of: rim))
            #expect(below < above)
        }
    }

    /// The hover rounds the corners its item rounds: a run's first
    /// item on a plate rounds its leading end alone.
    @Test("The hover takes its item's corners")
    func hoverTakesTheCorners() throws {
        let view = appItem(Self.shelf(glass: true), hovered: true)
        view.isFirstInRun = true
        view.isLastInRun = false
        view.layout()
        let item = try #require(view.layer?.maskedCorners)
        #expect(item != CACornerMask.allCorners)
        #expect(view.hoverFill.gradient?.maskedCorners == item)
    }
}

extension CACornerMask {
    fileprivate static let allCorners: CACornerMask = [
        .layerMinXMinYCorner, .layerMaxXMinYCorner,
        .layerMinXMaxYCorner, .layerMaxXMaxYCorner,
    ]
}
