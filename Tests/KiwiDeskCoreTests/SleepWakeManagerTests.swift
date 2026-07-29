import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The wake/unlock preserve-and-replay cycle, and its display
/// topology gate (#633). The rest/return pair is driven
/// directly — never through the real workspace notification
/// centers — and the restore wait uses a generous hang-guard
/// poll, never a tight deadline (#344).
@Suite("SleepWakeManager")
@MainActor
struct SleepWakeManagerTests {
    private func sample() -> StateSnapshot {
        StateSnapshot(
            windows: [
                .init(
                    id: WindowID(1),
                    frame: CGRect(
                        x: 1,
                        y: 2,
                        width: 3,
                        height: 4
                    )
                )
            ],
            spaces: [],
            activeSpace: "1"
        )
    }

    /// The shared generous hang-guard (#344): polls until
    /// `done` holds; 30 s bounds a genuine hang only — a
    /// passing run exits on the first true.
    private func pollUntil(
        _ done: @MainActor () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(30)
        while !done() && Date() < deadline {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    @Test("Wake replays the snapshot when displays are stable")
    func stableTopologyRestores() async {
        let manager = SleepWakeManager()
        manager.onLog = { _ in }
        manager.restoreDelayMS = 0
        let saved = sample()
        manager.captureState = { saved }
        manager.displayFingerprints = { ["main", "side"] }
        var restored: StateSnapshot?
        manager.restoreState = { restored = $0 }
        manager.systemWillRest()
        manager.systemDidReturn()
        await pollUntil { restored != nil }
        #expect(restored == saved)
    }

    @Test("Wake restore is skipped when the topology changed")
    func changedTopologySkips() async {
        let manager = SleepWakeManager()
        manager.restoreDelayMS = 0
        var logged: [String] = []
        manager.onLog = { logged.append($0) }
        manager.captureState = { self.sample() }
        var current = ["main", "side"]
        manager.displayFingerprints = { current }
        var restored = false
        manager.restoreState = { _ in restored = true }
        manager.systemWillRest()
        // The side monitor was unplugged while asleep.
        current = ["main"]
        manager.systemDidReturn()
        await pollUntil {
            logged.contains { $0.contains("topology") }
        }
        #expect(!restored)
        #expect(
            logged.contains {
                $0.contains("wake restore skipped")
            }
        )
    }

    @Test("Fingerprint order shuffle is not a topology change")
    func orderShuffleStillRestores() async {
        let manager = SleepWakeManager()
        manager.onLog = { _ in }
        manager.restoreDelayMS = 0
        manager.captureState = { self.sample() }
        var current = ["main", "side"]
        manager.displayFingerprints = { current }
        var restored = false
        manager.restoreState = { _ in restored = true }
        manager.systemWillRest()
        current = ["side", "main"]
        manager.systemDidReturn()
        await pollUntil { restored }
        #expect(restored)
    }
}
