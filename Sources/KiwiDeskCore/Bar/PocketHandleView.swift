import AppKit

/// The pocket's handle on an edge no bar shows (#2678, 2026-10-29
/// ruling): the two kiwis alone looking out from behind a short tab
/// lying flush on the screen edge, the pocket itself out of sight
/// (owner, device 2026-10-29), turned so they face the screen. The
/// tab wears a bar handle's two-tone ink at its depth, and runs no
/// progress fill (#3361 ruling 3). A fixed edge mark: it never
/// scales with the shelf and carries no count. An empty pocket's
/// fade is its panel's alone (#2678 review 18).
@MainActor
final class PocketHandleView: NSView {
    /// The tab's depth across the edge, a bar handle's (#3361), and
    /// its length along it.
    static var tabDepth: CGFloat { ShelfHandleSpec.depth }
    static let tabLength: CGFloat = 30
    /// The kiwis are drawn at the mark's grid at this side, their
    /// lower part behind the tab.
    static let markSide: CGFloat = 20
    /// How far the kiwis' image reaches past the tab at rest.
    static let lookOut: CGFloat = 5
    /// The handle's whole depth at rest: the tab and the kiwis past
    /// it.
    static var restDepth: CGFloat { tabDepth + lookOut }

    private var edge = AppBarEdge.bottom
    private var shelf = KiwiShelf()
    private var hex = ""
    /// The kiwis are out with the risen pocket: the tab alone stays.
    private var kiwisOut = false
    /// The pointer rests on the handle: the tab draws at full
    /// strength, in place (#3366 ruling 2).
    private(set) var hovered = false

    override var isFlipped: Bool { true }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setAccessibilityElement(false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    /// Wears `shelf`, the tab at full strength while `hovered`,
    /// which Core hands false while the pocket is risen.
    func wear(
        _ shelf: KiwiShelf,
        markHex hex: String,
        edge: AppBarEdge,
        kiwisOut: Bool,
        hovered: Bool = false
    ) {
        self.shelf = shelf
        self.hex = hex
        self.edge = edge
        self.kiwisOut = kiwisOut
        self.hovered = hovered
        needsDisplay = true
    }

    /// The tab's core: the handle's ink at rest, at the fill strength
    /// while hovered, never lifting (#3366 ruling 2).
    static func tabCore(hex: String, hovered: Bool) -> NSColor {
        hovered
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
        context.translateBy(x: bounds.midX, y: bounds.midY)
        context.rotate(by: Self.turn(for: edge))
        context.translateBy(x: -along / 2, y: -across / 2)
        let mark = PocketMark.kiwis.image(
            size: Self.markSide,
            hex: hex
        )
        let markRect = CGRect(
            x: (along - Self.markSide) / 2,
            y: across - Self.restDepth,
            width: Self.markSide,
            height: Self.markSide
        )
        if !kiwisOut {
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
                fraction: 1,
                respectFlipped: true,
                hints: nil
            )
            context.restoreGState()
        }
        let tab = CGRect(
            x: (along - Self.tabLength) / 2,
            y: across - Self.tabDepth,
            width: Self.tabLength,
            height: Self.tabDepth
        )
        let parts = ShelfHandleSpec.parts(of: tab)
        // A bar handle's ink, never the kiwis' own colour (#3361).
        let ink = ShelfHandleSpec.restHex(of: shelf)
        for (capsule, colour) in [
            (parts.outer, ShelfHandleSpec.hairlineColor(hex: ink)),
            (parts.core, Self.tabCore(hex: ink, hovered: hovered)),
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
