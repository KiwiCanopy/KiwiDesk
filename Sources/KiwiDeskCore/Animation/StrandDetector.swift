import CoreGraphics
import Foundation

/// Diagnostic read-back safety net detecting stranded window frames (#47).
@MainActor
final class StrandDetector {
    /// Reads a window's actual on-screen frame via AX.
    var frameReader: (WindowID) -> CGRect? = { _ in nil }

    /// Capture diagnostic sink — never `NSLog`, which macOS
    /// redacts in `log show` (#887; core-boundaries.md).
    var onLog: @MainActor (String) -> Void = CoreLog.write

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

    /// Records settled target and schedules post-grace read-back check (#47).
    func windowSettled(_ id: WindowID, target: CGRect) {
        guard isEnabled else { return }
        DispatchQueue.main.asyncAfter(
            deadline: .now() + graceSeconds
        ) { [weak self] in
            guard let self, let actual = self.frameReader(id)
            else { return }
            if !Self.landed(actual, on: target, within: tolerance) {
                self.onLog(
                    "STRAND: window \(id) target \(target) "
                        + "actual \(actual)"
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
