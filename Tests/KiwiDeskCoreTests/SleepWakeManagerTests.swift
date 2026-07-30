import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

@MainActor
private final class DisplayFingerprintState {
    var values: [String]

    init(_ values: [String]) {
        self.values = values
    }
}

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
        let displays = DisplayFingerprintState(["main", "side"])
        manager.displayFingerprints = { displays.values }
        var restored = false
        manager.restoreState = { _ in restored = true }
        manager.systemWillRest()
        // The side monitor was unplugged while asleep.
        displays.values = ["main"]
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
        let displays = DisplayFingerprintState(["main", "side"])
        manager.displayFingerprints = { displays.values }
        var restored = false
        manager.restoreState = { _ in restored = true }
        manager.systemWillRest()
        displays.values = ["side", "main"]
        manager.systemDidReturn()
        await pollUntil { restored }
        #expect(restored)
    }

    @Test("Losing one of two identical displays still skips")
    func identicalPairLossSkips() async {
        // Two same-model, same-resolution monitors share one
        // fingerprint string — a Set comparison would swallow
        // the loss of one; the multiset must not.
        let manager = SleepWakeManager()
        manager.restoreDelayMS = 0
        var logged: [String] = []
        manager.onLog = { logged.append($0) }
        manager.captureState = { self.sample() }
        let displays = DisplayFingerprintState(["twin", "twin"])
        manager.displayFingerprints = { displays.values }
        var restored = false
        manager.restoreState = { _ in restored = true }
        manager.systemWillRest()
        displays.values = ["twin"]
        manager.systemDidReturn()
        await pollUntil {
            logged.contains { $0.contains("topology") }
        }
        #expect(!restored)
        // The explicit skip line, so a return leg that
        // regresses to a no-op fails here instead of passing
        // vacuously after the poll's 30 s guard burns out.
        #expect(
            logged.contains {
                $0.contains("wake restore skipped")
            }
        )
    }
}

/// The wiring probe for the fail-open `displayFingerprints`
/// seam: unwired it returns `[]` forever, which compares equal
/// on both sides of the gate — restores keep firing while the
/// topology check silently never trips, the shipped-inert-seam
/// class the log-seam guards exist for. This asserts on the
/// value the wired seam actually returns for a seeded display,
/// so deleting the Bootstrap wiring line reds it.
@Suite("WakeFingerprintWiringTests")
@MainActor
struct WakeFingerprintWiringTests {
    @Test("Bootstrap wires the seam to live display state")
    func seamReturnsLiveFingerprints() {
        let core = makeTestCore()
        let display = Display(
            id: DisplayID(7),
            name: "Probe",
            frame: CGRect(x: 0, y: 0, width: 800, height: 600)
        )
        core.state.apply(.displaysChanged([display]))
        let expected = core.state.workspaces.allDisplays
            .map(\.fingerprint)
        #expect(!expected.isEmpty)
        #expect(
            core.sleepWake.displayFingerprints() == expected
        )
    }
}
