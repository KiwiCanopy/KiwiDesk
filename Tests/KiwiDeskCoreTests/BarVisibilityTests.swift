import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// `BarVisibility.judge` (#2234): visible, partly visible with the
/// side still on screen, or hidden — from frames alone.
@Suite("Bar visibility verdict")
struct BarVisibilityTests {
    private let screen = CGRect(x: 0, y: 0, width: 1000, height: 800)

    private func judge(
        _ frame: CGRect?,
        above: [CGRect] = []
    ) -> BarVisibility {
        BarVisibility.judge(frame, on: screen, above: above)
    }

    @Test("A window wholly on screen and uncovered is visible")
    func uncoveredIsVisible() {
        #expect(
            judge(CGRect(x: 10, y: 10, width: 400, height: 400))
                == .visible
        )
        #expect(judge(screen.insetBy(dx: -0.5, dy: -0.5)) == .visible)
    }

    @Test("A cut window names the side still on screen")
    func cutNamesTheSide() {
        let right = CGRect(x: 800, y: 0, width: 400, height: 800)
        #expect(judge(right) == .partly(shown: .left))
        let left = CGRect(x: -300, y: 0, width: 400, height: 800)
        #expect(judge(left) == .partly(shown: .right))
        let below = CGRect(x: 0, y: 600, width: 1000, height: 400)
        #expect(judge(below) == .partly(shown: .top))
        let above = CGRect(x: 0, y: -300, width: 1000, height: 400)
        #expect(judge(above) == .partly(shown: .bottom))
    }

    @Test("A window past the screen or unknown is hidden")
    func offScreenIsHidden() {
        #expect(
            judge(CGRect(x: 1200, y: 0, width: 400, height: 800))
                == .hidden
        )
        #expect(judge(nil) == .hidden)
    }

    @Test("A covered window is partly visible with no side")
    func overlapHasNoSide() {
        let window = CGRect(x: 0, y: 0, width: 600, height: 600)
        let float = CGRect(x: 400, y: 400, width: 400, height: 300)
        #expect(judge(window, above: [float]) == .partly(shown: nil))
        #expect(judge(window, above: [screen]) == .hidden)
        let touching = CGRect(x: 600, y: 0, width: 400, height: 600)
        #expect(judge(window, above: [touching]) == .visible)
    }

    @Test("A cover that contains the window hides it, in any order")
    func containingCoverWins() {
        let window = CGRect(x: 0, y: 0, width: 600, height: 600)
        let corner = CGRect(x: 400, y: 400, width: 400, height: 300)
        #expect(judge(window, above: [corner, screen]) == .hidden)
    }

    @Test("A window cut at both ends of an axis names no side")
    func bothEndsCutNameNoSide() {
        let wide = CGRect(x: -100, y: 0, width: 1200, height: 800)
        #expect(judge(wide) == .partly(shown: nil))
    }

    /// A cut window reads partly only past a scrolling row's edge
    /// sliver; a covered one only past a fifth uncovered.
    @Test("A sliver or an all but buried window reads hidden")
    func slivAndBuriedReadHidden() {
        let peek = ScrollingLayout.edgePeek
        let sliver = CGRect(x: 1000 - peek, y: 0, width: 200, height: 800)
        #expect(judge(sliver) == .hidden)
        let past = CGRect(x: 1000 - peek - 10, y: 0, width: 700, height: 800)
        #expect(judge(past) == .partly(shown: .left))
        let window = CGRect(x: 0, y: 0, width: 400, height: 400)
        let mostly = CGRect(x: 0, y: 0, width: 400, height: 330)
        #expect(judge(window, above: [mostly]) == .hidden)
        let half = CGRect(x: 0, y: 0, width: 400, height: 200)
        #expect(judge(window, above: [half]) == .partly(shown: nil))
    }

    /// Two covers each leaving more than a fifth uncovered read as
    /// the larger of them, not their union.
    @Test("Several covers read as the largest one")
    func coversReadAsTheLargest() {
        let window = CGRect(x: 0, y: 0, width: 400, height: 400)
        let top = CGRect(x: 0, y: 0, width: 400, height: 160)
        let bottom = CGRect(x: 0, y: 240, width: 400, height: 160)
        #expect(judge(window, above: [top, bottom]) == .partly(shown: nil))
    }

    /// A float: hidden when the region cuts it at all, ends both cut
    /// included; under the focused window hidden when wholly
    /// covered, partly with no side when overlapped at all, with no
    /// share floor; lit otherwise (#2234).
    @Test("A float reads cut, covered or lit")
    func floatVerdicts() {
        let focus = CGRect(x: 0, y: 0, width: 600, height: 600)
        let float = { (frame: CGRect) in
            BarVisibility.judgeFloat(frame, on: self.screen, under: focus)
        }
        #expect(
            float(CGRect(x: 100, y: 100, width: 200, height: 200)) == .hidden
        )
        #expect(
            float(CGRect(x: 500, y: 100, width: 200, height: 200))
                == .partly(shown: nil)
        )
        // Overlapped by most of the focus still shows the ring.
        #expect(
            float(CGRect(x: 0, y: 0, width: 620, height: 200))
                == .partly(shown: nil)
        )
        #expect(
            float(CGRect(x: 700, y: 100, width: 200, height: 200)) == .visible
        )
        #expect(
            float(CGRect(x: 900, y: 650, width: 300, height: 100)) == .hidden
        )
        let wide = CGRect(x: -100, y: 650, width: 1200, height: 100)
        #expect(float(wide) == .hidden)
        #expect(
            BarVisibility.judgeFloat(
                CGRect(x: 100, y: 100, width: 200, height: 200),
                on: screen,
                under: nil
            ) == .visible
        )
    }
}
