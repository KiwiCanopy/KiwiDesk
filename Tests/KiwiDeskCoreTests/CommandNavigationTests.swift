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
                candidates: candidates
            ) == nil
        )
        #expect(
            Navigation.neighbor(
                from: master,
                in: .down,
                candidates: candidates
            ) == nil
        )
        // Right still finds the stack (rows overlap).
        #expect(
            Navigation.neighbor(
                from: master,
                in: .right,
                candidates: candidates
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
                candidates: candidates
            ) == WindowID(1)
        )
        #expect(
            Navigation.neighbor(
                from: origin,
                in: .right,
                candidates: candidates
            ) == WindowID(2)
        )
        #expect(
            Navigation.neighbor(
                from: origin,
                in: .up,
                candidates: candidates
            ) == WindowID(3)
        )
        #expect(
            Navigation.neighbor(
                from: origin,
                in: .down,
                candidates: candidates
            ) == WindowID(4)
        )
    }

    @Test("Straight neighbors beat closer diagonal ones")
    func lateralPenalty() {
        let origin = frame(500, 500)
        let candidates: [(id: WindowID, frame: CGRect)] = [
            (WindowID(1), frame(650, 350)),
            (WindowID(2), frame(800, 500)),
        ]
        #expect(
            Navigation.neighbor(
                from: origin,
                in: .right,
                candidates: candidates
            ) == WindowID(2)
        )
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
                candidates: candidates
            ) == nil
        )
    }
}
