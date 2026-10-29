import AppKit

/// The pocket's handle on an edge no bar shows (#2678, 2026-10-29
/// ruling): the mark's two kiwis looking out from behind a short tab
/// lying on the screen edge, turned so they face the screen. A fixed
/// edge mark like the Space dots and the App Bar line — it never
/// scales with the shelf and carries no count; the kiwis fade while
/// the pocket is empty.
@MainActor
final class PocketHandleView: NSView {
    /// The tab's depth across the edge and length along it.
    static let tabDepth: CGFloat = 6
    static let tabLength: CGFloat = 30
    /// The kiwis are the mark drawn at this side, its lower part
    /// behind the tab.
    static let markSide: CGFloat = 20
    /// How far the kiwis look out past the tab.
    static let lookOut: CGFloat = 10
    /// The handle's whole depth at rest.
    static var restDepth: CGFloat { tabDepth + lookOut }

    private var edge = AppBarEdge.bottom
    private var shelf = KiwiShelf()
    private var hex = ""
    private var empty = false
    /// The kiwis are out with the risen pocket: the tab alone stays.
    private var kiwisOut = false

    override var isFlipped: Bool { true }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setAccessibilityElement(false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    func wear(
        _ shelf: KiwiShelf,
        markHex hex: String,
        edge: AppBarEdge,
        empty: Bool,
        kiwisOut: Bool
    ) {
        self.shelf = shelf
        self.hex = hex
        self.edge = edge
        self.empty = empty
        self.kiwisOut = kiwisOut
        needsDisplay = true
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
        let mark = PocketMark.mark.image(
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
            mark.draw(
                in: markRect,
                from: .zero,
                operation: .sourceOver,
                fraction: empty ? 0.5 : 1,
                respectFlipped: true,
                hints: nil
            )
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
        NSColor(kiwiFill: shelf.fillColor).withAlphaComponent(1).setFill()
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
