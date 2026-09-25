import AppKit
import QuartzCore

/// The coloured view `GlassTint.apply` places beneath a glass
/// surface (#1622). Its BACKING layer is the gradient, so the
/// fade resizes with the view's own frame animation — the shelf
/// plate's glide included — rather than as a sublayer that would
/// jump to the final size. It paints nothing itself: the colours
/// are `GlassTint`'s alone (#1297).
final class GlassBackdrop: NSView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        wantsLayer = true
    }

    convenience init() { self.init(frame: .zero) }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func makeBackingLayer() -> CALayer { CAGradientLayer() }

    /// The backing layer as the gradient it always is.
    var gradient: CAGradientLayer? { layer as? CAGradientLayer }
}
