import CoreGraphics
import Foundation

/// Safety net for the smooth-grow default (#47). When a window's
/// animation settles we set its exact target, but a slow-AX app
/// (Electron/WebKit) under load can drop or clamp that final set
/// and strand the window a few points off — the failure mode the
/// per-tick default risks. This reads the window back after a
/// grace and logs any window that didn't actually land, turning
/// device QA of the storm cases into pass/fail evidence.
///
/// Off unless `KIWIDESK_STRAND_LOG` is set, so it costs nothing in
/// production: no timer is scheduled and no AX read is made. The
/// read is deliberately post-grace and one-shot per settle.
///
/// Kept as a **permanent** net, not #47 scaffolding to remove: the
/// per-tick default's heavy-app stranding risk is real on hardware
/// we cannot all test, so leaving the probe wired (inert until the
/// env flag) means any future regression stays observable without a
/// rebuild. Module-internal — a Core diagnostic, not app API.
@MainActor
final class StrandDetector {
    /// Reads a window's actual on-screen frame (AX). Nil if the
    /// window is gone by the time the check fires.
    var frameReader: (WindowID) -> CGRect? = { _ in nil }

    /// Whether checks run. Driven from the environment at wiring.
    var isEnabled = false

    /// Per-edge slack (pt). Matches the applier's echo tolerance —
    /// below this a difference is AX rounding, not a strand.
    private let tolerance: CGFloat = 2

    /// Delay before the read-back, past the applier's echo grace so
    /// a legitimately-late final echo isn't misread as a strand.
    private let graceSeconds = 0.6

    init() {}

    /// Enable from the environment (`KIWIDESK_STRAND_LOG` set to any
    /// non-empty value). Call once at wiring.
    func configureFromEnvironment() {
        let value = ProcessInfo.processInfo
            .environment["KIWIDESK_STRAND_LOG"]
        isEnabled = !(value?.isEmpty ?? true)
    }

    /// Records a settled target and schedules the read-back check.
    /// No-op when disabled — the hot path stays free. Captures only
    /// `id` + `target`, no generation token: if a retile relocates
    /// the window inside the grace, the read-back compares the new
    /// (correct) frame to the stale target and can log a false
    /// strand. Acceptable for a QA logger — read a STRAND line as a
    /// lead to confirm, not proof.
    func windowSettled(_ id: WindowID, target: CGRect) {
        guard isEnabled else { return }
        DispatchQueue.main.asyncAfter(
            deadline: .now() + graceSeconds
        ) { [weak self] in
            guard let self, let actual = self.frameReader(id)
            else { return }
            if !Self.landed(actual, on: target, within: tolerance) {
                NSLog(
                    "KiwiDesk STRAND: window %@ target %@ actual %@",
                    String(describing: id),
                    String(describing: target),
                    String(describing: actual)
                )
            }
        }
    }

    /// True when every edge of `actual` is within `slack` of the
    /// target — i.e. the app landed where we set it. Pure math, so
    /// `nonisolated` — callable off the main actor (tests).
    nonisolated static func landed(
        _ actual: CGRect,
        on target: CGRect,
        within slack: CGFloat
    ) -> Bool {
        abs(actual.minX - target.minX) <= slack
            && abs(actual.minY - target.minY) <= slack
            && abs(actual.width - target.width) <= slack
            && abs(actual.height - target.height) <= slack
    }
}
