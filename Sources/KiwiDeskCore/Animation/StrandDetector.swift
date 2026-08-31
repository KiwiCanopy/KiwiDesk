import CoreGraphics
import Foundation

/// Diagnostic read-back safety net detecting stranded window
/// frames (#47). A PERMANENT net, not scaffolding to remove: the
/// per-tick default's heavy-app stranding risk is real on
/// hardware we cannot all test, so the probe stays wired (inert
/// until the env flag) and a future regression stays observable
/// without a rebuild.
@MainActor
final class StrandDetector {
    /// Reads a window's actual on-screen frame via AX.
    var frameReader: (WindowID) -> CGRect? = { _ in nil }

    /// Whether checks run (`KIWIDESK_STRAND_LOG`).
    var isEnabled = false

    /// Per-edge tolerance in points matching applier echo tolerance.
    private let tolerance: CGFloat = 2

    /// Delay before read-back check.
    private let graceSeconds = 0.6

    init() {}

    /// Configures diagnostic logging from `KIWIDESK_STRAND_LOG` environment.
    func configureFromEnvironment() {
        let value = ProcessInfo.processInfo
            .environment["KIWIDESK_STRAND_LOG"]
        isEnabled = !(value?.isEmpty ?? true)
    }

    /// Records settled target and schedules the post-grace
    /// read-back (#47). No generation token: a retile inside the
    /// grace can log a false strand — read a STRAND line as a
    /// lead to confirm, never proof.
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

    /// Checks if all edges of `actual` are within `slack` of `target`.
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
