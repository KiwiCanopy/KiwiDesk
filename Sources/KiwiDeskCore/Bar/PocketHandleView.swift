import AppKit

/// The pocket's handle on an edge no bar shows (#2678, 2026-10-29
/// ruling): the two kiwis alone looking out from behind a short tab
/// lying flush on the screen edge, the pocket itself out of sight
/// (owner, device 2026-10-29), turned so they face the screen. The
/// tab wears a bar handle's two-tone ink at its depth, and runs no
/// progress fill (#3361 ruling 3). A fixed edge mark: it never
/// scales with the shelf and carries no count. The tab is constant;
/// an empty pocket fades its kiwis alone (#3368 ruling 1).
@MainActor
final class PocketHandleView: NSView {
    /// The tab's depth across the edge, a bar handle's (#3361), and
    /// its length along it.
    static var tabDepth: CGFloat { ShelfHandleSpec.depth }
    static let tabLength: CGFloat = 30
    /// The kiwis are drawn at the mark's grid at this side, their
    /// lower part behind the tab.
    static let markSide: CGFloat = 20
    /// How far the kiwis' image reaches past the tab at rest: 3 pt
    /// further while the pocket `holds` something, the tab staying
    /// flush (#3446).
    static func lookOut(holds: Bool) -> CGFloat { holds ? 8 : 5 }
    /// The handle's whole depth at rest: the tab and the kiwis past
    /// it.
    static func restDepth(holds: Bool) -> CGFloat {
        tabDepth + lookOut(holds: holds)
    }

    private(set) var edge = AppBarEdge.bottom
    private(set) var shelf = KiwiShelf()
    private var hex = ""
    /// The kiwis are out with the risen pocket: the tab alone stays.
    private var kiwisOut = false
    /// The pointer rests on the handle: the tab draws at full
    /// strength, in place (#3366 ruling 2).
    private(set) var hovered = false
    /// The pocket is empty and unlit: the kiwis draw faded, the tab
    /// as ever (#3368 ruling 1).
    var faded = false {
        didSet { if faded != oldValue { needsDisplay = true } }
    }
    /// The pocket holds something: the tab rests at the fill strength
    /// (#3384).
    var holds = false {
        didSet { if holds != oldValue { needsDisplay = true } }
    }
    /// The pocket rising out of the tab or sinking back carries the
    /// kiwis meanwhile (#3368).
    var hidesKiwis = false {
        didSet { if hidesKiwis != oldValue { needsDisplay = true } }
    }

    /// The countdown run on the tab where the pocket's rise does not
    /// play (#3368 amended), and whether a new one waits to start.
    private(set) var fill: ShelfHandleSpec.Fill?
    var fillPending = false
    /// The tab's core capsule, which clips the fill running in it.
    let fillClip = CALayer()
    let fillLayer = CALayer()

    override var isFlipped: Bool { true }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setAccessibilityElement(false)
        wantsLayer = true
        fillClip.masksToBounds = true
        fillClip.addSublayer(fillLayer)
        fillLayer.isHidden = true
        layer?.addSublayer(fillClip)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    /// Wears `shelf`, the tab at full strength while `hovered`,
    /// which Core hands false while the pocket is risen, and running
    /// `fill` as its countdown.
    func wear(
        _ shelf: KiwiShelf,
        markHex hex: String,
        edge: AppBarEdge,
        kiwisOut: Bool,
        hovered: Bool = false,
        fill: ShelfHandleSpec.Fill? = nil
    ) {
        self.shelf = shelf
        self.hex = hex
        self.edge = edge
        self.kiwisOut = kiwisOut
        self.hovered = hovered
        if fill != self.fill { fillPending = true }
        self.fill = fill
        needsDisplay = true
        needsLayout = true
    }

    /// The tab's core: the handle's ink at rest, at the fill strength
    /// while `lit` — hovered, or the pocket holding something (#3384)
    /// — never lifting (#3366 ruling 2).
    static func tabCore(hex: String, lit: Bool) -> NSColor {
        lit
            ? ShelfHandleSpec.fillColor(hex: hex)
            : ShelfHandleSpec.restColor(hex: hex)
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else {
            return
        }
        // Laid out for a bottom edge, then turned to face the screen.
        let along = edge.isHorizontal ? bounds.width : bounds.height
        let across = edge.isHorizontal ? bounds.height : bounds.width
        context.saveGState()
        context.concatenate(drawingTurn())
        let mark = PocketMark.kiwis.image(
            size: Self.markSide,
            hex: hex
        )
        let markRect = CGRect(
            x: (along - Self.markSide) / 2,
            y: across - Self.restDepth(holds: holds),
            width: Self.markSide,
            height: Self.markSide
        )
        if !kiwisOut, !hidesKiwis {
            // Cut at the tab rather than covered by it: the tab's ink
            // is translucent, as a bar handle's is (#3361).
            context.saveGState()
            context.clip(
                to: CGRect(
                    x: 0,
                    y: 0,
                    width: along,
                    height: across - Self.tabDepth
                )
            )
            mark.draw(
                in: markRect,
                from: .zero,
                operation: .sourceOver,
                fraction: faded ? PocketPlateOverlay.fadedAlpha : 1,
                respectFlipped: true,
                hints: nil
            )
            context.restoreGState()
        }
        let parts = ShelfHandleSpec.parts(of: tabRect())
        // A bar handle's ink, never the kiwis' own colour (#3361).
        let ink = ShelfHandleSpec.restHex(of: shelf)
        for (capsule, colour) in [
            (parts.outer, ShelfHandleSpec.hairlineColor(hex: ink)),
            (parts.core, Self.tabCore(hex: ink, lit: hovered || holds)),
        ] {
            let radius = ShelfHandleSpec.radius(of: capsule)
            colour.setFill()
            NSBezierPath(
                roundedRect: capsule,
                xRadius: radius,
                yRadius: radius
            ).fill()
        }
        context.restoreGState()
    }

    /// The turn that takes the bottom-edge drawing onto `edge`, in a
    /// flipped view.
    static func turn(for edge: AppBarEdge) -> CGFloat {
        switch edge {
        case .bottom: 0
        case .top: .pi
        case .left: .pi / 2
        case .right: -.pi / 2
        }
    }
}
