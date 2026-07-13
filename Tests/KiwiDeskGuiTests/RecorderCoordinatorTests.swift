import Foundation
import Testing

@testable import KiwiDesk

/// The armed-edge contract behind the hotkey suspension safe win
/// (#213): `onArmedChange` fires exactly on the idle↔armed edge,
/// so the host suspends the live hotkeys once while a recorder is
/// open and restores them once when it closes — never bouncing
/// the Carbon registration while the user hops between fields.
@Suite("RecorderCoordinator armed edge")
@MainActor
struct RecorderCoordinatorTests {
    @Test("Switching fields stays armed; release disarms once")
    func armedEdges() {
        let coordinator = RecorderCoordinator()
        var events: [Bool] = []
        coordinator.onArmedChange = { events.append($0) }

        let a = UUID()
        let b = UUID()
        coordinator.claim(a) {}
        // A→B hands the claim over without leaving the armed
        // state — no restore/suspend churn.
        coordinator.claim(b) {}
        coordinator.release(b)

        #expect(events == [true, false])
    }

    @Test("Releasing a stale field id does not disarm")
    func staleRelease() {
        let coordinator = RecorderCoordinator()
        var events: [Bool] = []
        coordinator.onArmedChange = { events.append($0) }

        let a = UUID()
        let b = UUID()
        coordinator.claim(a) {}
        coordinator.release(b)  // not the active field — ignored
        #expect(events == [true])

        coordinator.release(a)
        #expect(events == [true, false])
    }

    @Test("Invalidate disarms an armed recorder")
    func invalidateDisarms() {
        let coordinator = RecorderCoordinator()
        var events: [Bool] = []
        coordinator.onArmedChange = { events.append($0) }

        coordinator.claim(UUID()) {}
        coordinator.invalidate()
        #expect(events == [true, false])
        // A second invalidate while idle stays idle.
        coordinator.invalidate()
        #expect(events == [true, false])
    }
}
