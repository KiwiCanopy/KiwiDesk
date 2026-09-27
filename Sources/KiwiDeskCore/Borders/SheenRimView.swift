import AppKit

/// A view that draws `BorderSheen`'s ramp across its bounds — as a
/// rim stroked inside them, flush with the edge the way a layer's
/// border sits, or as a fill (#1644). Drawn rather than masked so
/// the ramp re-draws with the view's own size. The host clears its
/// flat stroke or fill while a paint is set, or a translucent
/// colour would stack twice.
@MainActor
class SheenRimView: NSView {
    /// What the ramp paints: a rim `width` wide, or the whole
    /// bounds when nil, on the layer's own `cornerRadius`.
    struct Paint: Equatable {
        let hex: String
        let width: CGFloat?
        /// The signed sheen strength, never 0 (0 paints nothing).
        let strength: CGFloat
    }

    /// Nil draws nothing. Every write re-draws, since the host may
    /// have moved the corner radius the rim reads.
    var paint: Paint? {
        didSet {
            if paint != nil || oldValue != nil { needsDisplay = true }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        wantsLayer = true
        layerContentsRedrawPolicy = .duringViewResize
    }

    convenience init() { self.init(frame: .zero) }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func draw(_ dirtyRect: NSRect) {
        guard let paint,
            let context = NSGraphicsContext.current?.cgContext
        else { return }
        let inset = (paint.width ?? 0) / 2
        let rect = bounds.insetBy(dx: inset, dy: inset)
        guard rect.width > 0, rect.height > 0 else { return }
        let corner = layer?.cornerRadius ?? 0
        let radius = max(
            0,
            min(corner - inset, rect.width / 2, rect.height / 2)
        )
        BorderSheen.draw(
            CGPath(
                roundedRect: rect,
                cornerWidth: radius,
                cornerHeight: radius,
                transform: nil
            ),
            lineWidth: paint.width,
            extent: bounds,
            hex: paint.hex,
            strength: paint.strength,
            in: context
        )
    }
}
