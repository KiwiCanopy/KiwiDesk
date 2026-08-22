import CoreGraphics
import Testing

@testable import KiwiDeskCore

@Suite("Mouse resize translation")
struct MouseResizeTests {
    private let bounds = CGRect(
        x: 0,
        y: 25,
        width: 1000,
        height: 800
    )

    private func slot(
        x: CGFloat,
        width: CGFloat = 400,
        height: CGFloat = 700
    ) -> CGRect {
        CGRect(x: x, y: 25, width: width, height: height)
    }

    private func grown(
        _ rect: CGRect,
        dw: CGFloat = 0,
        dh: CGFloat = 0
    ) -> CGRect {
        CGRect(
            x: rect.minX,
            y: rect.minY,
            width: rect.width + dw,
            height: rect.height + dh
        )
    }

    @Test("Move gestures are not resizes")
    func moveIsNotResize() {
        let from = slot(x: 0)
        let to = from.offsetBy(dx: 300, dy: 40)
        #expect(!MouseResize.isResize(from: from, to: to))
        #expect(
            MouseResize.isResize(
                from: from,
                to: grown(from, dw: 50)
            )
        )
    }

    @Test("Growing the master grows the master ratio")
    func stackMaster() {
        let slot = slot(x: 0, width: 600)
        let adjustment = MouseResize.translate(
            mode: .stack,
            isMaster: true,
            stackSplitHorizontal: true,
            slot: slot,
            frame: grown(slot, dw: 100),
            bounds: bounds
        )
        #expect(adjustment == .masterRatio(0.1))
    }

    @Test("Growing a stack window shrinks the master ratio")
    func stackWindow() {
        let slot = slot(x: 600)
        let adjustment = MouseResize.translate(
            mode: .stack,
            isMaster: false,
            stackSplitHorizontal: true,
            slot: slot,
            frame: grown(slot, dw: 100),
            bounds: bounds
        )
        #expect(adjustment == .masterRatio(-0.1))
    }

    @Test("Stack height changes snap back")
    func stackHeight() {
        let slot = slot(x: 600, height: 300)
        let adjustment = MouseResize.translate(
            mode: .stack,
            isMaster: false,
            stackSplitHorizontal: true,
            slot: slot,
            frame: grown(slot, dh: 100),
            bounds: bounds
        )
        #expect(adjustment == nil)
    }

    @Test("A vertical split follows height drags (#222)")
    func stackVerticalSplitHeight() {
        let slot = slot(x: 0, width: 600, height: 300)
        let adjustment = MouseResize.translate(
            mode: .stack,
            isMaster: true,
            stackSplitHorizontal: false,
            slot: slot,
            frame: grown(slot, dh: 80),
            bounds: bounds
        )
        #expect(adjustment == .masterRatio(0.1))
    }

    @Test("A vertical split snaps width drags back (#222)")
    func stackVerticalSplitWidth() {
        let slot = slot(x: 0, width: 600, height: 300)
        let adjustment = MouseResize.translate(
            mode: .stack,
            isMaster: false,
            stackSplitHorizontal: false,
            slot: slot,
            frame: grown(slot, dw: 100),
            bounds: bounds
        )
        #expect(adjustment == nil)
    }

    @Test("BSP grows toward the dragged side")
    func bspSides() {
        let left = slot(x: 0)
        #expect(
            MouseResize.translate(
                mode: .bsp,
                isMaster: false,
                stackSplitHorizontal: true,
                slot: left,
                frame: grown(left, dw: 100),
                bounds: bounds
            ) == .bspRatioH(0.1)
        )
        let right = slot(x: 600)
        #expect(
            MouseResize.translate(
                mode: .bsp,
                isMaster: false,
                stackSplitHorizontal: true,
                slot: right,
                frame: grown(right, dw: 100),
                bounds: bounds
            ) == .bspRatioH(-0.1)
        )
    }

    @Test("BSP maps width drags to H and height drags to V")
    func bspAxes() {
        // A height-dominant drag on a top slot moves the
        // stacked (V) ratio, not the side-by-side one (#56).
        let top = CGRect(x: 0, y: 25, width: 900, height: 300)
        #expect(
            MouseResize.translate(
                mode: .bsp,
                isMaster: false,
                stackSplitHorizontal: true,
                slot: top,
                frame: grown(top, dh: 80),
                bounds: bounds
            ) == .bspRatioV(0.1)
        )
        // A bottom slot grows by lowering the V ratio.
        let bottom = CGRect(
            x: 0,
            y: 525,
            width: 900,
            height: 300
        )
        #expect(
            MouseResize.translate(
                mode: .bsp,
                isMaster: false,
                stackSplitHorizontal: true,
                slot: bottom,
                frame: grown(bottom, dh: 80),
                bounds: bounds
            ) == .bspRatioV(-0.1)
        )
    }

    @Test("Scrolling adjusts the column width")
    func scrolling() {
        let slot = slot(x: 100, width: 800)
        let adjustment = MouseResize.translate(
            mode: .scrolling,
            isMaster: false,
            stackSplitHorizontal: true,
            slot: slot,
            frame: grown(slot, dw: -150),
            bounds: bounds
        )
        #expect(adjustment == .scrollWidth(-150))
    }

    @Test("Track translates width/height drag by axis")
    func trackTranslation() {
        let slot = slot(x: 100, width: 400)
        #expect(
            MouseResize.translate(
                mode: .track,
                isMaster: false,
                stackSplitHorizontal: true,
                trackAxisVertical: true,
                slot: slot,
                frame: grown(slot, dw: 50),
                bounds: bounds
            ) == .trackAcross(50)
        )
        #expect(
            MouseResize.translate(
                mode: .track,
                isMaster: false,
                stackSplitHorizontal: true,
                trackAxisVertical: true,
                slot: slot,
                frame: grown(slot, dh: 80),
                bounds: bounds
            ) == .trackAlong(80)
        )
        #expect(
            MouseResize.translate(
                mode: .track,
                isMaster: false,
                stackSplitHorizontal: true,
                trackAxisVertical: false,
                slot: slot,
                frame: grown(slot, dh: 50),
                bounds: bounds
            ) == .trackAcross(50)
        )
        #expect(
            MouseResize.translate(
                mode: .track,
                isMaster: false,
                stackSplitHorizontal: true,
                trackAxisVertical: false,
                slot: slot,
                frame: grown(slot, dw: 80),
                bounds: bounds
            ) == .trackAlong(80)
        )
    }

    @Test("Grid and monocle have no resize parameter")
    func unsupportedModes() {
        let slot = slot(x: 0)
        for mode in [LayoutMode.grid, .monocle, .floating] {
            #expect(
                MouseResize.translate(
                    mode: mode,
                    isMaster: false,
                    stackSplitHorizontal: true,
                    slot: slot,
                    frame: grown(slot, dw: 100),
                    bounds: bounds
                ) == nil
            )
        }
    }
}
