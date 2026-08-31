import Foundation
import os

/// Signpost logging and interval metrics for boot path (`OSSignposter`, #672).
enum BootSignpost {
    /// Boot signposter. `KiwiLog.subsystem` must stay equal to
    /// the `.app`'s `CFBundleIdentifier` (scripts/build-app.sh
    /// writes that one): one subsystem predicate must find the log
    /// lines and these intervals together — whoever changes either
    /// changes both.
    static let signposter = OSSignposter(
        subsystem: KiwiLog.subsystem,
        category: "boot"
    )

    /// Threshold for logging slow attach/reconcile spans — the
    /// FLOOR of the Electron/WebKit lazy-answer band (100–300 ms,
    /// accessibility.md): a nontrivial warmup is itself boot-cost
    /// evidence, while fast native apps stay quiet.
    static let slowSpanMs: Int64 = 100
}

extension Duration {
    /// Whole milliseconds value for logging.
    var wholeMilliseconds: Int64 {
        components.seconds * 1_000
            + components.attoseconds / 1_000_000_000_000_000
    }
}
