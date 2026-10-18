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
        above: [CGRect] = [],
        parked: Bool = false
    ) -> BarVisibility {
        BarVisibility.judge(
            frame,
            on: screen,
            above: above,
            parked: parked
        )
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

    @Test("A window past the screen, parked or unknown is hidden")
    func offScreenIsHidden() {
        #expect(
            judge(CGRect(x: 1200, y: 0, width: 400, height: 800))
                == .hidden
        )
        #expect(
            judge(
                CGRect(x: 10, y: 10, width: 400, height: 400),
                parked: true
            ) == .hidden
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
}
