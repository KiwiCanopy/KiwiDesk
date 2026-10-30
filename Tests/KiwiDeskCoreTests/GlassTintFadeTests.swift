import AppKit
import Testing

@testable import KiwiDeskCore

/// **A Fill tints glass as a fade from the shelf's screen edge**
/// (#1622).
///
/// The anchor end carries the capped Fill and the far end
/// `GlassTint.floorShare` of it, toward the windows. The ends are
/// `GlassTintCapTests`'; these hold the DIRECTION, and hold it at
/// the consumers — the shelf plate and both bars' boxes — on a
/// non-default edge, since a call site that dropped the shelf's
/// edge for a constant would draw every shelf as a top shelf and
/// a top-edge fixture could not tell.
@Suite("Liquid Glass tint fade (#1622)", .serialized)
@MainActor
struct GlassTintFadeTests {
    /// The machine's Reduce transparency setting is a default this
    /// fixture reasons from, so it is pinned off (#660, #1374).
    init() { LiquidGlassGate.override = { false } }

    private static let frame = CGRect(x: 0, y: 0, width: 80, height: 24)

    /// Below macOS 26 nothing draws glass, so every clause would
    /// pass on a hidden backdrop.
    private static var drawsGlass: Bool {
        if #available(macOS 26, *) { return true }
        return false
    }

    /// Where the anchor sits in unit space, per edge — y up, as a
    /// layer-backed view's gradient reads it under a flipped and an
    /// unflipped superview alike (measured on screen, #1622).
    private static func anchor(_ edge: AppBarEdge) -> CGPoint {
        switch edge {
        case .top: CGPoint(x: 0.5, y: 1)
        case .bottom: CGPoint(x: 0.5, y: 0)
        case .left: CGPoint(x: 0, y: 0.5)
        case .right: CGPoint(x: 1, y: 0.5)
        }
    }

    /// The point opposite `point` through the unit square's centre.
    private static func opposite(_ point: CGPoint) -> CGPoint {
        CGPoint(x: 1 - point.x, y: 1 - point.y)
    }

    @Test(
        "The fade runs from the shelf's edge toward the windows",
        arguments: AppBarEdge.allCases
    )
    func fadeLeavesTheEdge(_ edge: AppBarEdge) throws {
        try #require(Self.drawsGlass, "no glass below macOS 26")
        let parent = NSView(frame: Self.frame)
        let glass = NSView(frame: Self.frame)
        parent.addSubview(glass)
        let backdrop = GlassBackdrop()
        GlassTint.apply(
            backdrop,
            in: glass,
            cornerRadius: 4,
            fill: GlassFill(hex: "#14201CB3"),
            edge: edge
        )
        let gradient = try #require(backdrop.gradient)
        #expect(gradient.startPoint == Self.anchor(edge), "\(edge)")
        #expect(
            gradient.endPoint == Self.opposite(Self.anchor(edge)),
            "\(edge)"
        )
        // The anchor end is the stronger one: a swapped colour
        // pair would draw the fade backwards with the right points.
        let alphas = (gradient.colors as? [CGColor] ?? []).map(\.alpha)
        try #require(alphas.count == 2, "\(alphas)")
        #expect(alphas[0] > alphas[1], "\(edge): \(alphas)")
    }

    // MARK: - The consumers

    private static func strip(_ edge: AppBarEdge) -> CGRect {
        edge.isHorizontal
            ? barTitleStrip
            : CGRect(x: 0, y: 0, width: 28, height: 1440)
    }

    @Test("The shelf plate fades from the shelf's own edge")
    func shelfPlateTakesTheEdge() throws {
        try #require(Self.drawsGlass, "no glass below macOS 26")
        // Not `.bottom`: its anchor is `CAGradientLayer`'s default
        // `startPoint`, which an unpainted backdrop also carries.
        let edge = AppBarEdge.right
        let spaces = SpaceBarManager()
        spaces.sync([
            paintedSpaceBar(edge: edge, front: nil, spaces: 3, glass: true)
        ])
        let section = try #require(spaces.shownOverlay(on: barTitleDisplay))
        var shelf = KiwiShelf()
        shelf.fillColor = "#14201CB3"
        shelf.liquidGlass = true
        shelf.backgroundStyle = .plain
        let shelves = ShelfManager()
        shelves.sync([
            ShelfManager.Shelf(
                display: barTitleDisplay,
                edge: edge,
                strip: Self.strip(edge),
                shelf: shelf,
                sheen: 0,
                space: section,
                app: nil
            )
        ])
        let overlay = try #require(
            shelves.overlayForTesting(barTitleDisplay)
        )
        let tint = try #require(overlay.glassTint)
        try #require(
            !tint.isHiddenOrHasHiddenAncestor,
            "the shelf's tint was not painted"
        )
        #expect(tint.gradient?.startPoint == Self.anchor(edge))
    }

    @Test("A boxed Space Bar's boxes and front segment fade from the edge")
    func spaceBarBoxesTakeTheEdge() throws {
        try #require(Self.drawsGlass, "no glass below macOS 26")
        let edge = AppBarEdge.left
        var bar = paintedSpaceBar(edge: edge, front: WindowID(1), spaces: 2)
        var style = bar.style
        style.liquidGlass = true
        style.backgroundStyle = .boxed
        bar = SpaceBarManager.Bar(
            display: bar.display,
            items: bar.items,
            frontApp: bar.frontApp,
            frontWindow: bar.frontWindow,
            strip: Self.strip(edge),
            style: style,
            stateMarkColors: bar.stateMarkColors
        )
        let manager = SpaceBarManager()
        manager.sync([bar])
        let overlay = try #require(manager.shownOverlay(on: barTitleDisplay))
        let tints = overlay.boxTints.filter {
            !$0.isHiddenOrHasHiddenAncestor
        }
        try #require(!tints.isEmpty, "no box was tinted")
        for tint in tints {
            #expect(tint.gradient?.startPoint == Self.anchor(edge))
        }
        // The front-app segment's box is the fourth call site.
        let front = try #require(overlay.frontTint, "no front glass")
        #expect(front.gradient?.startPoint == Self.anchor(edge))
    }

    @Test("A boxed App Bar's boxes fade from the shelf's edge")
    func appBarBoxesTakeTheEdge() throws {
        try #require(Self.drawsGlass, "no glass below macOS 26")
        let edge = AppBarEdge.right
        let painted = paintedAppBar(
            edge: edge,
            items: [
                appBarItem(1, text: "One"), appBarItem(2, text: "Two"),
            ]
        )
        var style = painted.style
        style.liquidGlass = true
        style.backgroundStyle = .boxed
        let bar = AppBarManager.Bar(
            display: painted.display,
            space: painted.space,
            items: painted.items,
            activeIndex: painted.activeIndex,
            strip: Self.strip(edge),
            style: style,
            capAxis: Self.strip(edge).height
        )
        let manager = AppBarManager()
        manager.sync([bar])
        let overlay = try #require(manager.shownOverlay(on: barTitleDisplay))
        let tints = overlay.boxTints.filter {
            !$0.isHiddenOrHasHiddenAncestor
        }
        try #require(!tints.isEmpty, "no box was tinted")
        for tint in tints {
            #expect(tint.gradient?.startPoint == Self.anchor(edge))
        }
    }

    // MARK: - The hover peek (#1946, #2569)

    /// The first tint under `view`, at any depth: a glass carries
    /// its tint as its content (#2569).
    private static func backdrop(in view: NSView) -> GlassBackdrop? {
        for sub in view.subviews {
            if let tint = sub as? GlassBackdrop { return tint }
            if let tint = backdrop(in: sub) { return tint }
        }
        return nil
    }

    /// Both ends' alphas of a painted backdrop.
    private static func alphas(_ tint: GlassBackdrop) -> [CGFloat] {
        (tint.gradient?.colors as? [CGColor] ?? []).map(\.alpha)
    }

    /// The consumer: the hover peek fades like the bar, from the
    /// shelf's edge (#2569, overturning #1946's uniform tint).
    @Test(
        "The hover peek's glass fades from the shelf's edge",
        arguments: [false, true]
    )
    func peekFadesFromTheEdge(increaseContrast: Bool) throws {
        try #require(Self.drawsGlass, "no glass below macOS 26")
        LiquidGlassGate.contrastOverride = { increaseContrast }
        defer { LiquidGlassGate.contrastOverride = nil }
        var shelf = KiwiShelf()
        shelf.fillColor = "#14201CB3"
        shelf.liquidGlass = true
        shelf.backgroundStyle = .plain
        try #require(shelf.glassEnabled)
        let peek = BarPeekPanel()
        defer { peek.panel?.orderOut(nil) }
        peek.show(
            BarPeekContent(
                rows: [
                    BarWindowRow(
                        window: WindowID(1),
                        pid: 1,
                        app: "App",
                        title: "One",
                        icon: nil
                    )
                ]
            ),
            shelf: shelf,
            edge: .bottom,
            anchor: CGRect(x: 300, y: 10, width: 20, height: 20),
            strip: CGRect(x: 0, y: 0, width: 1440, height: 40),
            visible: CGRect(x: 0, y: 0, width: 1440, height: 900),
            fades: false
        )
        // The panel draws on its stage, a grown list's clip (#2563).
        let tint = try #require(
            Self.backdrop(in: peek.stage),
            "the peek has no tint"
        )
        try #require(
            !tint.isHiddenOrHasHiddenAncestor,
            "the peek's tint was not painted"
        )
        #expect(tint.gradient?.startPoint == Self.anchor(.bottom))
        let alphas = Self.alphas(tint)
        try #require(alphas.count == 2, "\(alphas)")
        #expect(alphas[0] >= alphas[1], "\(alphas)")
        // The reading floor stops the fade (#2569 ▸ Ruling); under
        // Increase Contrast the default Fill paints flat.
        let floor = shelf.readingGlassFill(
            increaseContrast: increaseContrast
        ).minShare
        try #require(floor > GlassTint.farShare(fade: 100))
        #expect(abs(alphas[1] / alphas[0] - floor) < 0.001, "\(alphas)")
    }
}
