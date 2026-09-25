import AppKit
import QuartzCore

/// The coloured view `GlassTint.apply` places beneath a glass
/// surface (#1622). Its BACKING layer is the gradient, so the fade
/// follows the view's own frame animation (bars.md). It paints
/// nothing itself — the colours are `GlassTint`'s alone (#1297,
/// `GlassTintCensusTests` ▸ `backdropPaintsNothing`).
final class GlassBackdrop: NSView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        wantsLayer = true
        clipsToBounds = true
    }

    convenience init() { self.init(frame: .zero) }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func makeBackingLayer() -> CALayer { CAGradientLayer() }

    /// The backing layer as the gradient it always is.
    var gradient: CAGradientLayer? { layer as? CAGradientLayer }
}
