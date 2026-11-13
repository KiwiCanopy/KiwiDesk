import CoreGraphics
import Testing

@testable import KiwiDeskCore

@Suite("Navigation")
struct NavigationTests {
    private func frame(
        _ x: CGFloat,
        _ y: CGFloat
    ) -> CGRect {
        CGRect(x: x, y: y, width: 100, height: 100)
    }

    @Test("No cross-column jump without cross-axis overlap")
    func requiresOverlap() {
        // Full-height master, two stack windows to the right.
        let master = CGRect(x: 0, y: 0, width: 500, height: 1000)
        let candidates: [(id: WindowID, frame: CGRect)] = [
            (WindowID(2), CGRect(x: 510, y: 0, width: 300, height: 490)),
            (WindowID(3), CGRect(x: 510, y: 510, width: 300, height: 490)),
        ]
        // Up/down from the master must fail, not jump into
        // the stack column diagonally.
        #expect(
            Navigation.neighbor(
                from: master,
                in: .up,
                candidates: candidates,
                tie: .none
            ) == nil
        )
        #expect(
            Navigation.neighbor(
                from: master,
                in: .down,
                candidates: candidates,
                tie: .none
            ) == nil
        )
        // Right still finds the stack (rows overlap).
        #expect(
            Navigation.neighbor(
                from: master,
                in: .right,
                candidates: candidates,
                tie: .none
            ) != nil
        )
    }

    @Test("Finds the straight neighbor in each direction")
    func straightNeighbors() {
        let origin = frame(500, 500)
        let candidates: [(id: WindowID, frame: CGRect)] = [
            (WindowID(1), frame(300, 500)),
            (WindowID(2), frame(700, 500)),
            (WindowID(3), frame(500, 300)),
            (WindowID(4), frame(500, 700)),
        ]
        #expect(
            Navigation.neighbor(
                from: origin,
                in: .left,
                candidates: candidates,
                tie: .none
            ) == WindowID(1)
        )
        #expect(
            Navigation.neighbor(
                from: origin,
                in: .right,
                candidates: candidates,
                tie: .none
            ) == WindowID(2)
        )
        #expect(
            Navigation.neighbor(
                from: origin,
                in: .up,
                candidates: candidates,
                tie: .none
            ) == WindowID(3)
        )
        #expect(
            Navigation.neighbor(
                from: origin,
                in: .down,
                candidates: candidates,
                tie: .none
            ) == WindowID(4)
        )
    }

    /// The closer window overlaps the origin by a sliver, so the
    /// lateral term, not the overlap guard, decides.
    @Test("Straight neighbors beat closer diagonal ones")
    func lateralPenalty() {
        let origin = frame(500, 500)
        let candidates: [(id: WindowID, frame: CGRect)] = [
            (WindowID(1), frame(650, 401)),
            (WindowID(2), frame(800, 500)),
        ]
        #expect(
            Navigation.neighbor(
                from: origin,
                in: .right,
                candidates: candidates,
                tie: .none
            ) == WindowID(2)
        )
    }

    /// A window lying across the origin's center line reads
    /// straight however far its own center sits, in all four
    /// directions (#3207): drawn for `.right` and turned about the
    /// origin's center for the rest.
    @Test("A window across the center line reads straight")
    func spanningWindowIsStraight() {
        let origin = frame(500, 500)
        // Nearer, and tall: its center is 250 pt off the line.
        let across = CGRect(x: 700, y: 0, width: 100, height: 600)
        // Farther, centered on the line.
        let ahead = frame(900, 500)
        for direction in Direction.allCases {
            let turn = { (rect: CGRect) in
                Self.turned(rect, to: direction, about: 550)
            }
            #expect(
                Navigation.neighbor(
                    from: turn(origin),
                    in: direction,
                    candidates: [
                        (WindowID(1), turn(across)),
                        (WindowID(2), turn(ahead)),
                    ],
                    tie: .none
                ) == WindowID(1),
                "\(direction)"
            )
        }
    }

    /// An edge lying on the center line is no crossing: with no
    /// inner gap the column's two halves meet on it, and the half
    /// whose center is nearer the line still wins.
    @Test("An edge on the center line is no crossing")
    func edgeOnTheLineIsNoCrossing() {
        let origin = CGRect(x: 500, y: 0, width: 500, height: 500)
        let candidates: [(id: WindowID, frame: CGRect)] = [
            (WindowID(2), CGRect(x: 0, y: 250, width: 500, height: 750)),
            (WindowID(1), CGRect(x: 0, y: 0, width: 500, height: 250)),
        ]
        #expect(
            Navigation.neighbor(
                from: origin,
                in: .left,
                candidates: candidates,
                tie: .none
            ) == WindowID(1)
        )
    }

    /// `rect`, drawn facing `.right`, turned to face `direction`
    /// about the point (`c`, `c`).
    private static func turned(
        _ rect: CGRect,
        to direction: Direction,
        about c: CGFloat
    ) -> CGRect {
        switch direction {
        case .right:
            rect
        case .left:
            CGRect(
                x: 2 * c - rect.maxX,
                y: rect.minY,
                width: rect.width,
                height: rect.height
            )
        case .down:
            CGRect(
                x: rect.minY,
                y: rect.minX,
                width: rect.height,
                height: rect.width
            )
        case .up:
            CGRect(
                x: rect.minY,
                y: 2 * c - rect.maxX,
                width: rect.height,
                height: rect.width
            )
        }
    }

    @Test("No neighbor in an empty direction")
    func emptyDirection() {
        let origin = frame(500, 500)
        let candidates: [(id: WindowID, frame: CGRect)] = [
            (WindowID(1), frame(700, 500))
        ]
        #expect(
            Navigation.neighbor(
                from: origin,
                in: .left,
                candidates: candidates,
                tie: .none
            ) == nil
        )
    }
}
