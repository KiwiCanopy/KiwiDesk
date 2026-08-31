import Foundation
import os

/// Signpost logging and interval metrics for boot path (`OSSignposter`, #672).
enum BootSignpost {
    /// Boot signposter configured with shared subsystem (`KiwiLog.subsystem`).
    static let signposter = OSSignposter(
        subsystem: KiwiLog.subsystem,
        category: "boot"
    )

    /// Threshold in milliseconds for logging slow attach/reconcile spans.
    static let slowSpanMs: Int64 = 100
}

extension Duration {
    /// Whole milliseconds value for logging.
    var wholeMilliseconds: Int64 {
        components.seconds * 1_000
            + components.attoseconds / 1_000_000_000_000_000
    }
}
