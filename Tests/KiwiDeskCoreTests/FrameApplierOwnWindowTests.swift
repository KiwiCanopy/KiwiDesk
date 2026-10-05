import ApplicationServices
import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// KiwiDesk's own window moves inside the caller's turn (#1956):
/// an own-pid write used to ride the main queue, so a Space
/// switch's park of the Settings window ran only after the
/// switch's own turn, and under load the window stood alone on
/// the new Space until it ended.
@Suite("Own windows move in the caller's turn (#1956)", .serialized)
@MainActor
struct FrameApplierOwnWindowTests {
    private let w = WindowID(1)
    private let frame = CGRect(x: 10, y: 20, width: 300, height: 200)

    private final class Moves {
        var all: [(WindowID, CGRect, Bool)] = []
    }

    private func makeApplier(
        pid: pid_t,
        _ moves: Moves,
        answers: Bool = true
    ) -> FrameApplier {
        let applier = FrameApplier()
        let element = AXUIElementCreateApplication(pid)
        applier.elementProvider = { _ in element }
        applier.ownWindowMove = {
            moves.all.append(($0, $1, $2))
            return answers
        }
        // Nothing reaches a real app.
        applier.writer = FrameWriter(
            setFrame: { _, _ in },
            setPosition: { _, _ in },
            writeEUI: { _, _ in }
        )
        return applier
    }

    @Test("an own window's instant write moves it before the call returns")
    func ownWindowMovesNow() {
        let moves = Moves()
        let applier = makeApplier(pid: getpid(), moves)
        applier.applyInstant(w, frame, setSize: false)
        #expect(moves.all.count == 1)
        #expect(moves.all.first?.1 == frame)
        #expect(moves.all.first?.2 == false)
    }

    @Test("another app's window never takes the AppKit move")
    func otherAppTakesTheQueue() {
        let moves = Moves()
        let applier = makeApplier(pid: 1, moves)
        applier.applyInstant(w, frame, setSize: true)
        #expect(moves.all.isEmpty)
    }

    @Test("a held own window moves at its landing, through AppKit")
    func heldOwnWindowMovesAtTheLanding() async throws {
        let moves = Moves()
        let applier = makeApplier(pid: getpid(), moves)
        applier.holdWrites([w], until: .now() + 0.05)
        applier.applyInstant(w, frame, setSize: true)
        #expect(moves.all.isEmpty)
        // A generous guard, never a tight deadline (#344).
        for _ in 0..<500 where moves.all.isEmpty {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(moves.all.count == 1)
        #expect(moves.all.first?.2 == true)
    }
}
