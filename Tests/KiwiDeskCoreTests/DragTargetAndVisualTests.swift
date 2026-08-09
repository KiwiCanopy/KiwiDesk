import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

@Suite("Drag visual configuration", .serialized)
@MainActor
struct DragVisualCommandTests {
    private func makeCore() -> KiwiCore {
        makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-dragviz-\(UUID().uuidString)"
                )
        )
    }

    @Test("drag.* commands update every visual setting")
    func commands() {
        let core = makeCore()
        core.execute(
            "drag.set_ghost_enabled",
            args: [.bool(false)]
        )
        core.execute(
            "drag.set_ghost_fill_color",
            args: [.string("#112233")]
        )
        core.execute(
            "drag.set_ghost_border_width",
            args: [.number(4)]
        )
        // `outside` is the value the ghost does NOT ship with,
        // so the assertion below cannot pass on the default.
        core.execute(
            "drag.set_ghost_border_alignment",
            args: [.string("outside")]
        )
        core.execute(
            "drag.set_drop_zone_border_width",
            args: [.number(3)]
        )
        core.execute(
            "drag.set_drop_zone_border",
            args: [.bool(false)]
        )
        core.execute(
            "drag.set_corner_radius",
            args: [.number(26)]
        )
        let settings = core.tiler.settings
        #expect(!settings.dragGhost.enabled)
        #expect(settings.dragGhost.fillColor == "#112233")
        #expect(settings.dragGhost.borderWidth == 4)
        #expect(settings.dragGhost.borderAlignment == .outside)
        #expect(settings.dragDropZone.borderWidth == 3)
        // Per stroke, not per pair: the ghost was moved
        // `.outside` above and the drop zone stays on the
        // shipped default, `.inside`.
        #expect(
            settings.dragDropZone.borderAlignment == .inside
        )
        #expect(!settings.dragDropZone.border)
        #expect(settings.dragCornerRadius == 26)
    }

    @Test("Bad colors and unknown settings are rejected")
    func rejectsBadInput() {
        let core = makeCore()
        #expect(
            !core.execute(
                "drag.set_ghost_border_color",
                args: [.string("kiwi")]
            ).isSuccess
        )
        #expect(
            !core.execute(
                "drag.set_ghost_opacity",
                args: [.number(1)]
            ).isSuccess
        )
        #expect(
            core.tiler.settings.dragGhost
                == .ghostDefault
        )
    }
}

@Suite("Hex color parsing")
struct HexColorTests {
    @Test("6- and 8-digit hex parse, junk does not")
    func parse() throws {
        let rgb = try #require(
            DragVisual.parseHex("#4E9F3D")
        )
        #expect(rgb.alpha == 1)
        #expect(abs(rgb.green - 0x9F / 255.0) < 0.001)
        let rgba = try #require(
            DragVisual.parseHex("8B5E3C40")
        )
        #expect(abs(rgba.alpha - 0x40 / 255.0) < 0.001)
        #expect(DragVisual.parseHex("#12345") == nil)
        #expect(DragVisual.parseHex("kiwi") == nil)
        #expect(DragVisual.parseHex("#GG5E3C") == nil)
    }
}

@Suite("Drag target rule")
struct DragTargetTests {
    private let slots: [WindowID: CGRect] = [
        WindowID(1): CGRect(x: 0, y: 0, width: 100, height: 100),
        WindowID(2): CGRect(
            x: 100,
            y: 0,
            width: 100,
            height: 100
        ),
    ]

    @Test("The slot under the cursor is the target")
    func cursorRule() {
        // Cursor over slot 2's area.
        let cursor = CGPoint(x: 130, y: 50)
        #expect(
            DragTarget.swapTarget(
                of: WindowID(1),
                at: cursor,
                slots: slots
            ) == WindowID(2)
        )
    }

    @Test(
        """
        Target follows the cursor onto the destination display \
        even while the dragged window's center trails behind \
        on the origin display (#492)
        """
    )
    func cursorLeadsOverCenter() {
        // A big window on the origin display dragged toward a
        // smaller one. Its center still sits over the origin
        // slot, but the cursor has already crossed to the
        // destination slot.
        let origin = CGRect(x: 0, y: 0, width: 2000, height: 1000)
        let dest = CGRect(
            x: 2000,
            y: 0,
            width: 800,
            height: 600
        )
        let pool: [WindowID: CGRect] = [
            WindowID(2): origin,
            WindowID(3): dest,
        ]
        let windowCenter = CGPoint(x: 900, y: 500)
        let cursor = CGPoint(x: 2400, y: 300)
        // The old center rule would have picked the origin slot,
        // never resolving the destination.
        #expect(origin.contains(windowCenter))
        #expect(!dest.contains(windowCenter))
        // The cursor rule lands on the destination slot.
        #expect(
            DragTarget.swapTarget(
                of: WindowID(1),
                at: cursor,
                slots: pool
            ) == WindowID(3)
        )
    }

    @Test("A window's own slot is never its target")
    func neverSelf() {
        // Cursor over slot 1 (the dragged window's own slot).
        let cursor = CGPoint(x: 30, y: 30)
        #expect(
            DragTarget.swapTarget(
                of: WindowID(1),
                at: cursor,
                slots: slots
            ) == nil
        )
    }

    @Test("A cursor over no slot yields no target")
    func nowhere() {
        let cursor = CGPoint(x: 500, y: 500)
        #expect(
            DragTarget.swapTarget(
                of: WindowID(1),
                at: cursor,
                slots: slots
            ) == nil
        )
    }

    @Test(
        """
        Overlapping cascade slots resolve to the visible \
        strip's owner, not dictionary order
        """
    )
    func cascadeOverlap() {
        // A stack overflow cascade: same column, each slot 40
        // lower than the previous, all 100 tall — so slot n's
        // visible part is the 40-point strip under its top.
        let cascade: [WindowID: CGRect] = [
            WindowID(2): CGRect(
                x: 0,
                y: 0,
                width: 100,
                height: 100
            ),
            WindowID(3): CGRect(
                x: 0,
                y: 40,
                width: 100,
                height: 100
            ),
            WindowID(4): CGRect(
                x: 0,
                y: 80,
                width: 100,
                height: 100
            ),
        ]
        func target(centerY: CGFloat) -> WindowID? {
            DragTarget.swapTarget(
                of: WindowID(1),
                at: CGPoint(x: 50, y: centerY),
                slots: cascade
            )
        }
        // Inside the top window's exposed strip.
        #expect(target(centerY: 20) == WindowID(2))
        // Two slots contain this point; the middle window's
        // strip is the visible one.
        #expect(target(centerY: 60) == WindowID(3))
        // All three contain this point; the last window is
        // raised on top of the whole cascade.
        #expect(target(centerY: 90) == WindowID(4))
    }

    @Test("Identical slots pick a deterministic target")
    func identicalSlots() {
        let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
        let same: [WindowID: CGRect] = [
            WindowID(2): rect,
            WindowID(3): rect,
        ]
        let cursor = CGPoint(x: 50, y: 50)
        for _ in 0..<10 {
            #expect(
                DragTarget.swapTarget(
                    of: WindowID(1),
                    at: cursor,
                    slots: same
                ) == WindowID(3)
            )
        }
    }
}
