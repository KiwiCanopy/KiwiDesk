import AppKit
import CoreGraphics
import QuartzCore
import Testing

@testable import KiwiDeskCore

/// The sticky mark's pill pops as it expands (#421), and the pop
/// stays inside its panel — #2033's clip class, which the mark
/// had with a panel sized exactly to the plate. The pop runs
/// DURING the animated expand, so the clause is held at every
/// point of it: the room and the plate animate together from the
/// collapsed mark to the pill.
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

    /// The mark's right edge stays put while the pill grows left.
    private func mark(width: CGFloat) -> CGRect {
        CGRect(x: 900 - width, y: 500, width: width, height: Self.height)
    }

    @Test(
        "every keyframe stays inside the panel through the expand",
        arguments: [CGPoint.zero, CGPoint(x: 0.5, y: 0.5)]
    )
    func popStaysInside(anchor: CGPoint) {
        let collapsed = mark(width: Self.height)
        for width in [120.0, 240.0, StickyMarkPlate.maxWidth] as [CGFloat] {
            let pill = mark(width: width)
            let fromRoom = StickyMarkOverlay.panelFrame(for: collapsed)
            let toRoom = StickyMarkOverlay.panelFrame(for: pill)
            for step in 0...10 {
                let p = CGFloat(step) / 10
                let room = mix(fromRoom, toRoom, p)
                let plate = mix(collapsed, pill, p)
                let inRoom = PopRoom.plateFrame(plate: plate, in: room)
                let bounds = CGRect(origin: .zero, size: room.size)
                for scale in StickyMarkOverlay.popKeyframes.map(\.scale) {
                    let t = PopRoom.transform(
                        scale: scale,
                        size: plate.size,
                        anchor: anchor
                    )
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
                        let at = CGPoint(
                            x: inRoom.minX + q.x,
                            y: inRoom.minY + q.y
                        )
                        #expect(
                            bounds.insetBy(dx: 0.5, dy: 0.5).contains(at),
                            "width \(width), p \(p), scale \(scale)"
                        )
                    }
                }
            }
        }
    }

    /// The pop still pops: room is what the peak needs, not a
    /// scale clamped to 1.
    @Test("the pop grows past the resting size")
    func popGrows() {
        #expect(StickyMarkOverlay.popPeak > 1)
    }

    /// The overlay hosts the plate in that room, at the mark's
    /// resting place: never the panel's content view itself.
    @Test("the plate rides a room inside the panel")
    func plateRidesTheRoom() throws {
        let overlay = StickyMarkOverlay(window: 1)
        let frame = CGRect(x: 200, y: 200, width: 800, height: 600)
        overlay.update(frame: frame)
        defer { overlay.hide() }
        let room = try #require(overlay.plate.superview)
        #expect(room !== overlay.plate)
        let plate = overlay.plate.frame
        let grown = plate.insetBy(
            dx: -plate.width * (StickyMarkOverlay.popPeak - 1) / 2,
            dy: -plate.height * (StickyMarkOverlay.popPeak - 1) / 2
        )
        #expect(room.bounds.contains(grown))
        #expect(plate.size == CGSize(width: Self.height, height: Self.height))
    }
}
