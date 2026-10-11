import CoreGraphics
import QuartzCore
import Testing

@testable import KiwiDeskCore

/// The refusal pill's entrance pop stays inside its panel (#2033):
/// at every keyframe scale, about whichever anchor AppKit gives
/// the plate's layer, the plate's corners stay inside the panel
/// `panelFrame` sizes, and its centre does not move.
@Suite("Size limit pill pop")
struct SizeLimitPillPopTests {
    /// Where `point` (layer-local) lands under `t`, applied about
    /// the anchor the way Core Animation does.
    private func apply(
        _ t: CATransform3D,
        to point: CGPoint,
        size: CGSize,
        anchor: CGPoint
    ) -> CGPoint {
        let a = CGPoint(x: anchor.x * size.width, y: anchor.y * size.height)
        let x = point.x - a.x
        let y = point.y - a.y
        return CGPoint(
            x: a.x + x * t.m11 + y * t.m21 + t.m41,
            y: a.y + x * t.m12 + y * t.m22 + t.m42
        )
    }

    @Test(
        "every keyframe stays inside the panel, centred",
        arguments: [CGPoint.zero, CGPoint(x: 0.5, y: 0.5)]
    )
    func popStaysInside(anchor: CGPoint) {
        for width in [120.0, 200.0, 480.0] as [CGFloat] {
            let pill = CGRect(x: 300, y: 40, width: width, height: 26)
            let panel = SizeLimitOverlay.panelFrame(for: pill)
            // The plate, in the panel's own coordinates.
            let origin = CGPoint(
                x: pill.minX - panel.minX,
                y: pill.minY - panel.minY
            )
            let bounds = CGRect(origin: .zero, size: panel.size)
            for scale in SizeLimitOverlay.popScales {
                let t = SizeLimitOverlay.popTransform(
                    scale: scale,
                    size: pill.size,
                    anchor: anchor
                )
                let corners = [
                    CGPoint.zero,
                    CGPoint(x: width, y: 0),
                    CGPoint(x: 0, y: 26),
                    CGPoint(x: width, y: 26),
                ]
                for corner in corners {
                    let p = apply(
                        t,
                        to: corner,
                        size: pill.size,
                        anchor: anchor
                    )
                    let inPanel = CGPoint(
                        x: origin.x + p.x,
                        y: origin.y + p.y
                    )
                    #expect(
                        bounds.insetBy(dx: 0.5, dy: 0.5)
                            .contains(inPanel),
                        "scale \(scale), width \(width)"
                    )
                }
                let centre = CGPoint(x: width / 2, y: 13)
                let moved = apply(
                    t,
                    to: centre,
                    size: pill.size,
                    anchor: anchor
                )
                #expect(abs(moved.x - centre.x) < 0.001)
                #expect(abs(moved.y - centre.y) < 0.001)
            }
        }
    }

    /// The pop still pops: the panel margin is what the peak needs,
    /// not a scale clamped to 1.
    @Test("the pop grows past the resting size")
    func popGrows() {
        #expect((SizeLimitOverlay.popScales.max() ?? 1) > 1)
    }
}
