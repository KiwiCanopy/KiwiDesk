import AppKit

/// The half-moon (#2234): a small disc just before an App Bar
/// item's icon — above it on a vertical bar — drawn only while the
/// item's window is partly visible. The half on the side of the
/// window still on screen is filled; a window covered without a
/// side draws the ring alone. Its slot is reserved on every item,
/// so no item's length changes with it.
final class AppBarHalfMoon: NSView {
    let ring = CAShapeLayer()
    let half = CAShapeLayer()

    override var isFlipped: Bool { true }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        ring.fillColor = nil
        ring.lineWidth = 1
        layer?.addSublayer(half)
        layer?.addSublayer(ring)
        isHidden = true
        setAccessibilityElement(false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:)") }

    /// The disc's diameter for a strip whose content depth is
    /// `contentDepth`: a quarter of it, never below 5 pt.
    nonisolated static func diameter(contentDepth: CGFloat) -> CGFloat {
        max(5, contentDepth * 0.25)
    }

    /// The length the disc's slot takes along the run on every
    /// item: the disc and the icon spacing after it.
    nonisolated static func reserve(contentDepth: CGFloat) -> CGFloat {
        diameter(contentDepth: contentDepth)
            + AppBarItemView.contentPadding / 2
    }

    private var drawn: (side: BarVisibility.Side?, ink: NSColor)?

    /// Shows the disc for `visibility` in `ink`, at full alpha
    /// whatever the item's dim; redrawn at every size it is laid
    /// out at.
    func show(_ visibility: BarVisibility, ink: NSColor) {
        guard case .partly(let shown) = visibility else {
            drawn = nil
            isHidden = true
            return
        }
        drawn = (shown, ink)
        isHidden = false
        needsLayout = true
    }

    override func layout() {
        super.layout()
        guard let drawn else { return }
        let box = bounds.insetBy(dx: 0.5, dy: 0.5)
        ring.frame = bounds
        half.frame = bounds
        ring.strokeColor = drawn.ink.cgColor
        half.fillColor = drawn.ink.cgColor
        ring.path = CGPath(ellipseIn: box, transform: nil)
        half.path = drawn.side.map { Self.halfPath(in: box, side: $0) }
    }

    /// The half of the disc in `box` on `side`, in this view's
    /// flipped space (y grows down, so `.top` is the low y).
    nonisolated static func halfPath(
        in box: CGRect,
        side: BarVisibility.Side
    ) -> CGPath {
        let path = CGMutablePath()
        let centre = CGPoint(x: box.midX, y: box.midY)
        let radius = box.width / 2
        let start: CGFloat
        switch side {
        case .left: start = .pi / 2
        case .right: start = -.pi / 2
        case .top: start = .pi
        case .bottom: start = 0
        }
        path.move(to: centre)
        path.addArc(
            center: centre,
            radius: radius,
            startAngle: start,
            endAngle: start + .pi,
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}
