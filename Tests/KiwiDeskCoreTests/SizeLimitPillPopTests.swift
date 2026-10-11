import AppKit
import CoreGraphics
import QuartzCore
import Testing

@testable import KiwiDeskCore

/// The refusal pill's entrance pop stays inside its panel (#2033):
/// at every keyframe scale, about whichever anchor AppKit gives
/// the plate's layer, the plate's corners stay inside the panel
/// `PopRoom.panelFrame` sizes, and its centre does not move.
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
            let panel = PopRoom.panelFrame(
                for: pill,
                scales: SizeLimitOverlay.popKeyframes.map(\.scale)
            )
            // The plate, in the panel's own coordinates, where
            // `flash` puts it.
            let plate = PopRoom.plateFrame(plate: pill, in: panel)
            let origin = plate.origin
            let bounds = CGRect(origin: .zero, size: panel.size)
            for scale in SizeLimitOverlay.popKeyframes.map(\.scale) {
                let t = PopRoom.transform(
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
        let scales = SizeLimitOverlay.popKeyframes.map(\.scale)
        #expect((scales.max() ?? 1) > 1)
    }

    /// The plate keeps its resting place on screen: the panel only
    /// grows around it.
    @Test("the plate sits where the pill rests")
    func plateRestsInPlace() {
        let pill = CGRect(x: 300, y: 40, width: 200, height: 26)
        let panel = PopRoom.panelFrame(
            for: pill,
            scales: SizeLimitOverlay.popKeyframes.map(\.scale)
        )
        let plate = PopRoom.plateFrame(plate: pill, in: panel)
        #expect(plate.offsetBy(dx: panel.minX, dy: panel.minY) == pill)
    }

    /// The overlay's own call site: a pill `flash` shows sits in
    /// a room with space for the peak, inside the panel's content
    /// view and never as it.
    @Test("a flashed pill rests in a room with space for the pop")
    @MainActor
    func flashedPillHasRoom() throws {
        let overlay = SizeLimitOverlay()
        let shown = overlay.flash(
            window: 1,
            frame: CGRect(x: 200, y: 200, width: 800, height: 600),
            text: "Can't be any smaller",
            symbol: "nosign"
        )
        try #require(shown)
        let pill = try #require(overlay.pillForTest(1))
        let content = try #require(pill.content)
        #expect(content !== pill.plate)
        #expect(pill.plate.superview === content)
        let plate = pill.plate.frame
        let peak = SizeLimitOverlay.popKeyframes.map(\.scale).max() ?? 1
        let grown = plate.insetBy(
            dx: -plate.width * (peak - 1) / 2,
            dy: -plate.height * (peak - 1) / 2
        )
        #expect(CGRect(origin: .zero, size: pill.panel.size).contains(grown))
    }
}
