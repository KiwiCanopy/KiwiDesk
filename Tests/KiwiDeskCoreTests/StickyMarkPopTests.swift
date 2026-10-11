import AppKit
import CoreGraphics
import QuartzCore
import Testing

@testable import KiwiDeskCore

/// The sticky mark's pill pops as it expands (#421), and the pop
/// stays inside its panel — #2033's clip class, which the mark
/// had with a panel sized exactly to the plate. The pop runs
/// DURING the animated expand, so the clause reads the transforms
/// the overlay added and holds them at every point of the plate's
/// resize inside the panel it set.
@Suite("Sticky mark pop")
@MainActor
struct StickyMarkPopTests {
    /// The pop plays only with Reduce Motion off.
    nonisolated private static let motionOn = !NSWorkspace.shared
        .accessibilityDisplayShouldReduceMotion
    private static let height = StickyMarkOverlay.size

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

    private func mix(_ a: CGRect, _ b: CGRect, _ p: CGFloat) -> CGRect {
        CGRect(
            x: a.minX + (b.minX - a.minX) * p,
            y: a.minY + (b.minY - a.minY) * p,
            width: a.width + (b.width - a.width) * p,
            height: a.height + (b.height - a.height) * p
        )
    }

    /// The plate's corners, scaled by each keyframe the overlay
    /// ACTUALLY added, at every point of the resize from `from` to
    /// `to` (panel coordinates), stay inside the panel.
    private func expectInside(
        _ pop: CAKeyframeAnimation,
        anchor: CGPoint,
        from: CGRect,
        to: CGRect,
        panel: CGSize
    ) {
        let bounds = CGRect(origin: .zero, size: panel)
        let transforms = (pop.values ?? []).compactMap {
            ($0 as? NSValue)?.caTransform3DValue
        }
        #expect(transforms.count == StickyMarkOverlay.popKeyframes.count)
        for step in 0...10 {
            let plate = mix(from, to, CGFloat(step) / 10)
            for t in transforms {
                for corner in [
                    CGPoint.zero,
                    CGPoint(x: plate.width, y: 0),
                    CGPoint(x: 0, y: plate.height),
                    CGPoint(x: plate.width, y: plate.height),
                ] {
                    let q = apply(
                        t,
                        to: corner,
                        size: plate.size,
                        anchor: anchor
                    )
                    let at = CGPoint(x: plate.minX + q.x, y: plate.minY + q.y)
                    #expect(
                        bounds.insetBy(dx: 0.5, dy: 0.5).contains(at),
                        "width \(to.width), step \(step)"
                    )
                }
            }
        }
    }

    /// The pop the expand adds, read off the plate's layer: its
    /// transforms against the plate as it resizes inside the panel
    /// the overlay set, from the collapsed mark to the pill.
    @Test(
        "the expand's pop stays inside the panel",
        .enabled(if: motionOn)
    )
    func expandPopStaysInside() throws {
        let frame = CGRect(x: 200, y: 200, width: 900, height: 600)
        for width in [120.0, 240.0, StickyMarkPlate.maxWidth] as [CGFloat] {
            let overlay = StickyMarkOverlay(window: 1)
            overlay.update(frame: frame)
            defer { overlay.hide() }
            let collapsed = overlay.plate.frame.size
            overlay.setPillForTest(width: width, nameShown: true)
            let panel = try #require(overlay.panelFrameForTest)
            let layer = try #require(overlay.plate.layer)
            let pop = try #require(
                layer.animation(forKey: "entrancePop")
                    as? CAKeyframeAnimation
            )
            let to = overlay.plate.frame
            // The pill grows left from the mark's right edge.
            let from = CGRect(
                x: to.maxX - collapsed.width,
                y: to.minY,
                width: collapsed.width,
                height: collapsed.height
            )
            expectInside(
                pop,
                anchor: layer.anchorPoint,
                from: from,
                to: to,
                panel: panel.size
            )
        }
    }

    /// Room is what the peak needs, never a scale clamped to 1.
    @Test("the pop grows past the resting size")
    func popGrows() {
        let scales = StickyMarkOverlay.popKeyframes.map(\.scale)
        #expect((scales.max() ?? 1) > 1)
    }

    /// The overlay hosts the plate in a room, never as the panel's
    /// content view: a plate the panel's size clips its own pop.
    @Test("the plate rests inside a room with space for the pop")
    func plateRestsInTheRoom() throws {
        let overlay = StickyMarkOverlay(window: 1)
        overlay.update(frame: CGRect(x: 200, y: 200, width: 800, height: 600))
        defer { overlay.hide() }
        let panel = try #require(overlay.panelFrameForTest)
        let plate = overlay.plate.frame
        let peak = StickyMarkOverlay.popKeyframes.map(\.scale).max() ?? 1
        let grown = plate.insetBy(
            dx: -plate.width * (peak - 1) / 2,
            dy: -plate.height * (peak - 1) / 2
        )
        #expect(CGRect(origin: .zero, size: panel.size).contains(grown))
        #expect(plate.size == CGSize(width: Self.height, height: Self.height))
    }
}
