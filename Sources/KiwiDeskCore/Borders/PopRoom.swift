import CoreGraphics
import QuartzCore

/// Room for a cue's entrance pop inside its panel (#2033): a
/// plate scaled past its resting size by a panel sized exactly to
/// it is clipped at the panel's edge. The refusal pill and the
/// sticky mark's pill both take it.
enum PopRoom {
    /// The panel frame hosting a plate resting at `plate` that
    /// pops through `scales`: grown on each side by what the
    /// peak adds, plus a point, so the scaled plate never meets
    /// the edge. The peak is read off the scales the cue plays.
    static func panelFrame(
        for plate: CGRect,
        scales: [CGFloat]
    ) -> CGRect {
        let grow = max(scales.max() ?? 1, 1) - 1
        return plate.insetBy(
            dx: -ceil(plate.width * grow / 2) - 1,
            dy: -ceil(plate.height * grow / 2) - 1
        )
    }

    /// Where the plate sits inside the panel's own coordinates:
    /// its resting rect, unmoved on screen.
    static func plateFrame(
        plate: CGRect,
        in panel: CGRect
    ) -> CGRect {
        CGRect(
            x: plate.minX - panel.minX,
            y: plate.minY - panel.minY,
            width: plate.width,
            height: plate.height
        )
    }

    /// Scales a layer of `size` by `scale` about its CENTRE,
    /// whatever its `anchor` — a layer-backed view's layer keeps
    /// AppKit's anchor, which a hand-set one does not survive.
    static func transform(
        scale: CGFloat,
        size: CGSize,
        anchor: CGPoint
    ) -> CATransform3D {
        let dx = (0.5 - anchor.x) * size.width * (1 - scale)
        let dy = (0.5 - anchor.y) * size.height * (1 - scale)
        return CATransform3DConcat(
            CATransform3DMakeScale(scale, scale, 1),
            CATransform3DMakeTranslation(dx, dy, 0)
        )
    }
}
