import CoreGraphics
import Foundation
import os

/// The one door to the public window list (#2634). The read waits
/// on this process's pending window updates while holding the
/// WindowServer connection lock (os-private-apis.md, #2531), so
/// every read names its call site and one past `slowThreshold`
/// logs the site and thread, attributing a stalled turn to the read
/// that held it. The line goes to the unified log through
/// own `Logger`, never `KiwiCore.onLog`: reads run off the main
/// actor, which that seam's `@MainActor` closure cannot take.
enum WindowListRead {
    static let slowThreshold: Duration = .milliseconds(50)

    private static let logger = Logger(
        subsystem: KiwiLog.subsystem,
        category: "window-list"
    )

    /// The `KiwiDesk: ` prefix is what capture tooling greps for.
    static func write(_ message: String) {
        logger.log("KiwiDesk: \(message, privacy: .public)")
    }

    static func copy(
        _ site: String,
        _ options: CGWindowListOption,
        relativeTo window: CGWindowID = kCGNullWindowID
    ) -> [[String: Any]]? {
        timed(site) {
            CGWindowListCopyWindowInfo(options, window)
                as? [[String: Any]]
        }
    }

    /// `read`, timed; the clock, the sink and the thread are
    /// parameters so a test drives the slow branch exactly.
    static func timed(
        _ site: String,
        now: () -> ContinuousClock.Instant = { .now },
        onMain: Bool = Thread.isMainThread,
        log: (String) -> Void = WindowListRead.write,
        read: () -> [[String: Any]]?
    ) -> [[String: Any]]? {
        let start = now()
        let list = read()
        let took = start.duration(to: now())
        if took >= slowThreshold {
            let ms = Int(took / .milliseconds(1))
            let thread = onMain ? "main" : "off main"
            log("window-list read \(site): \(ms) ms \(thread)")
        }
        return list
    }
}
