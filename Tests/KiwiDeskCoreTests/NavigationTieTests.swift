import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// The tie rule of a directional step (#2619): an origin spanning
/// several of the nearest candidates, or an equal score, goes back
/// to the last step's window, else the first tied in flat order.
@Suite("Navigation tie (#2619)")
struct NavigationTieTests {
    /// Full-height master, a stack column of three to its right.
    private let master = CGRect(x: 0, y: 0, width: 500, height: 900)
    private let stack: [(id: WindowID, frame: CGRect)] = [
        (WindowID(2), CGRect(x: 510, y: 0, width: 300, height: 290)),
        (WindowID(3), CGRect(x: 510, y: 300, width: 300, height: 300)),
        (WindowID(4), CGRect(x: 510, y: 610, width: 300, height: 290)),
    ]
    private let order: [WindowID: Int] = [
        WindowID(1): 0, WindowID(2): 1, WindowID(3): 2, WindowID(4): 3,
    ]

    @Test("Untied, the middle wins; tied, the first in order")
    func spanningOriginTakesTheFirst() {
        #expect(
            Navigation.neighbor(
                from: master,
                in: .right,
                candidates: stack,
                tie: .none
            ) == WindowID(3)
        )
        #expect(
            Navigation.neighbor(
                from: master,
                in: .right,
                candidates: stack,
                tie: .init(order: order)
            ) == WindowID(2)
        )
    }

    @Test("The last step's window wins a tie it is in")
    func lastStepReturns() {
        #expect(
            Navigation.neighbor(
                from: master,
                in: .right,
                candidates: stack,
                tie: .init(returnTo: WindowID(4), order: order)
            ) == WindowID(4)
        )
    }

    @Test("A last step outside the tie is ignored")
    func lastStepElsewhereFallsToOrder() {
        #expect(
            Navigation.neighbor(
                from: master,
                in: .right,
                candidates: stack,
                tie: .init(returnTo: WindowID(9), order: order)
            ) == WindowID(2)
        )
    }

    @Test("The first in order wins from either side")
    func orderNotDistance() {
        // Window 4 full height on the right, 1–3 stacked left.
        let origin = CGRect(x: 510, y: 0, width: 500, height: 900)
        let left: [(id: WindowID, frame: CGRect)] = stack.map {
            (
                WindowID($0.id.raw - 1),
                $0.frame.offsetBy(dx: -510, dy: 0)
            )
        }
        #expect(
            Navigation.neighbor(
                from: origin,
                in: .left,
                candidates: left,
                tie: .init(order: order)
            ) == WindowID(1)
        )
    }

    @Test("An origin spanning one candidate keeps the geometry")
    func shortOriginKeepsTheGeometry() {
        let origin = CGRect(x: 0, y: 610, width: 500, height: 290)
        #expect(
            Navigation.neighbor(
                from: origin,
                in: .right,
                candidates: stack,
                tie: .init(order: order)
            ) == WindowID(4)
        )
    }

    @Test("An equal score is a tie")
    func equalScoreTies() {
        // A middle third facing two halves.
        let origin = CGRect(x: 0, y: 300, width: 500, height: 300)
        let halves: [(id: WindowID, frame: CGRect)] = [
            (WindowID(5), CGRect(x: 510, y: 0, width: 300, height: 450)),
            (WindowID(4), CGRect(x: 510, y: 450, width: 300, height: 450)),
        ]
        #expect(
            Navigation.neighbor(
                from: origin,
                in: .right,
                candidates: halves,
                tie: .init(order: [WindowID(4): 0, WindowID(5): 1])
            ) == WindowID(4)
        )
    }

    @Test("Only the nearest candidates tie")
    func fartherColumnIsNoTie() {
        let far: [(id: WindowID, frame: CGRect)] = [
            (WindowID(0), CGRect(x: 820, y: 0, width: 200, height: 290))
        ]
        #expect(
            Navigation.neighbor(
                from: master,
                in: .right,
                candidates: stack + far,
                tie: .init(
                    order: order.merging([WindowID(0): -1]) {
                        first,
                        _ in first
                    }
                )
            ) == WindowID(2)
        )
    }

    @Test("Rounding in the slots still ties")
    func roundingStillTies() {
        let origin = CGRect(x: 0, y: 0.4, width: 500, height: 899.2)
        let rounded: [(id: WindowID, frame: CGRect)] = [
            (WindowID(2), CGRect(x: 511.5, y: 0, width: 300, height: 290)),
            (WindowID(3), CGRect(x: 510.3, y: 300, width: 300, height: 300)),
            (WindowID(4), CGRect(x: 511, y: 610, width: 300, height: 290)),
        ]
        #expect(
            Navigation.neighbor(
                from: origin,
                in: .right,
                candidates: rounded,
                tie: .init(order: order)
            ) == WindowID(2)
        )
    }

    @Test("Beside maps by centre: top to top, bottom to bottom")
    func besideMapsByCentre() {
        let top = CGRect(x: 0, y: 0, width: 500, height: 445)
        let bottom = CGRect(x: 0, y: 455, width: 500, height: 445)
        let tie = Navigation.TieBreak(order: order)
        #expect(
            Navigation.beside(
                top,
                crossIsY: true,
                candidates: stack,
                tie: tie
            ) == WindowID(2)
        )
        #expect(
            Navigation.beside(
                bottom,
                crossIsY: true,
                candidates: stack,
                tie: tie
            ) == WindowID(4)
        )
        #expect(
            Navigation.beside(
                master,
                crossIsY: true,
                candidates: stack,
                tie: tie
            ) == WindowID(2)
        )
    }
}
