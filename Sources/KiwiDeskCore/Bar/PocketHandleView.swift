import AppKit

/// The pocket's handle on an edge no bar shows (#2678, 2026-10-29
/// ruling): the two kiwis alone looking out from behind a short tab
/// lying on the screen edge, the pocket itself out of sight (owner,
/// device 2026-10-29), turned so they face the screen. A fixed
/// edge mark like the Space dots and the App Bar line — it never
/// scales with the shelf and carries no count. An empty pocket's
/// fade is its panel's alone (#2678 review 18).
@MainActor
final class PocketHandleView: NSView {
    /// The tab's depth across the edge and length along it.
    static let tabDepth: CGFloat = 6
    static let tabLength: CGFloat = 30
    /// The kiwis are drawn at the mark's grid at this side, their
    /// lower part behind the tab.
    static let markSide: CGFloat = 20
    /// The handle's whole depth at rest, `PocketMarkGeometry`'s.
    static var restDepth: CGFloat { PocketMarkGeometry.handleDepth }
    /// How far the kiwis' image reaches past the tab at rest.
    static var lookOut: CGFloat { restDepth - tabDepth }
    /// How much further they look out while the pointer is on the
    /// handle and the pocket has not risen (#2807).
    static let peekDepth: CGFloat = 3

    /// How far the kiwis look out past their rest, animated by
    /// `BarMotion.playPocketPeek` through the view's animator.
    @objc dynamic var peek: CGFloat = 0 {
        didSet { needsDisplay = true }
    }
    /// The peek `peek` is headed for.
    var peekTarget: CGFloat = 0

    private var edge = AppBarEdge.bottom
    private var shelf = KiwiShelf()
    private var hex = ""
    /// The kiwis are out with the risen pocket: the tab alone stays.
    private var kiwisOut = false

    override var isFlipped: Bool { true }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setAccessibilityElement(false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    /// Wears `shelf`; true where the kiwis move and `landed` will
    /// run once they stand.
    @discardableResult
    func wear(
        _ shelf: KiwiShelf,
        markHex hex: String,
        edge: AppBarEdge,
        kiwisOut: Bool,
        peeking: Bool = false,
        landed: (@MainActor () -> Void)? = nil
    ) -> Bool {
        self.shelf = shelf
        self.hex = hex
        self.edge = edge
        self.kiwisOut = kiwisOut
        needsDisplay = true
        return BarMotion.playPocketPeek(
            self,
            peeking: peeking && !kiwisOut,
            landed: landed
        )
    }

    override static func defaultAnimation(
        forKey key: NSAnimatablePropertyKey
    ) -> Any? {
        key == "peek"
            ? BarMotion.pocketPeekAnimation()
            : super.defaultAnimation(forKey: key)
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
            y: across - Self.restDepth - peek,
            width: Self.markSide,
            height: Self.markSide
        )
        if !kiwisOut {
            // Cut at the tab rather than covered by it: the tab wears
            // the Fill as the bars' handles do, its alpha kept (#2776).
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
        let path = NSBezierPath(
            roundedRect: tab,
            xRadius: Self.tabDepth / 2,
            yRadius: Self.tabDepth / 2
        )
        NSColor(kiwiFill: shelf.fillColor).setFill()
        path.fill()
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
