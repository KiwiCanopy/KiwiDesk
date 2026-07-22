import Foundation
import Testing

@testable import KiwiDeskCore

/// `KiwiCore.setMissionControlActive` is the single writer that keeps
/// the pull-gate (`missionControlActive`, guarding the `update*()`
/// refreshes) and the ring's push-gate (`borders.suspended`, guarding
/// the WindowServer event stream) in lockstep. The end-to-end hide is
/// device-QA (real Mission Control); these pin the coordination seam.
@Suite("Mission Control overlay suspension", .serialized)
@MainActor
struct MissionControlCoordinationTests {
    private func makeCore() -> KiwiCore {
        KiwiCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent("kiwi-mc-\(UUID().uuidString)")
        )
    }

    @Test("Entering suspends the ring push-gate")
    func enterSuspends() {
        let core = makeCore()
        #expect(!core.missionControlActive)
        #expect(!core.borders.suspended)
        core.setMissionControlActive(true)
        #expect(core.missionControlActive)
        #expect(core.borders.suspended)
    }

    @Test("Exiting clears both gates")
    func exitResumes() {
        let core = makeCore()
        core.setMissionControlActive(true)
        core.setMissionControlActive(false)
        #expect(!core.missionControlActive)
        #expect(!core.borders.suspended)
    }

    @Test("Re-entering is idempotent")
    func reenterIdempotent() {
        let core = makeCore()
        core.setMissionControlActive(true)
        core.setMissionControlActive(true)
        #expect(core.missionControlActive)
        #expect(core.borders.suspended)
    }
}
