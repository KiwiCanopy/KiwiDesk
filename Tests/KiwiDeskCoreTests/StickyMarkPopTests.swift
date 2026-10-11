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

    /// An overlay showing its collapsed mark, Reduce Motion off.
    private func overlay() -> StickyMarkOverlay {
        let overlay = StickyMarkOverlay(window: 1)
        overlay.readReduceMotion = { false }
        overlay.update(
            frame: CGRect(x: 200, y: 200, width: 900, height: 600)
        )
        return overlay
    }

    /// The plate's rect, re-expressed in the panel the overlay set
    /// after `before` was read.
    private func moved(
        _ plate: CGRect,
        from before: CGRect,
        to after: CGRect
    ) -> CGRect {
        plate.offsetBy(
            dx: before.minX - after.minX,
            dy: before.minY - after.minY
        )
    }

    /// The pop the expand adds, read off the plate's layer: its
    /// transforms against the plate as it resizes inside the panel
    /// the overlay set, from where it rested to the pill.
    @Test("the expand's pop stays inside the panel")
    func expandPopStaysInside() throws {
        for width in [120.0, 240.0, StickyMarkPlate.maxWidth] as [CGFloat] {
            let overlay = overlay()
            defer { overlay.hide() }
            let before = try #require(overlay.panelFrameForTest)
            let rest = overlay.plate.frame
            overlay.setPillForTest(width: width, nameShown: true)
            let panel = try #require(overlay.panelFrameForTest)
            let layer = try #require(overlay.plate.layer)
            let pop = try #require(
                layer.animation(forKey: "entrancePop")
                    as? CAKeyframeAnimation
            )
            expectInside(
                pop,
                anchor: layer.anchorPoint,
                from: moved(rest, from: before, to: panel),
                to: overlay.plate.frame,
                panel: panel.size
            )
        }
    }

    /// The collapse shrinks the pill back to the mark: the panel
    /// it sets holds the plate where it starts and where it lands,
    /// or the shrinking plate is clipped at the panel's edge.
    @Test("the collapse keeps the shrinking plate inside the panel")
    func collapseStaysInside() throws {
        let overlay = overlay()
        defer { overlay.hide() }
        let mark = overlay.plate.frame.width
        overlay.setPillForTest(width: 240, nameShown: true)
        let before = try #require(overlay.panelFrameForTest)
        let pill = overlay.plate.frame
        overlay.setPillForTest(width: mark, nameShown: false)
        let panel = try #require(overlay.panelFrameForTest)
        let bounds = CGRect(origin: .zero, size: panel.size)
        #expect(bounds.contains(moved(pill, from: before, to: panel)))
        #expect(bounds.contains(overlay.plate.frame))
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
