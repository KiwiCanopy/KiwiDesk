import CoreGraphics
import Foundation

/// The one door to the public window list (#2634). The read waits
/// on this process's pending window updates while holding the
/// WindowServer connection lock, so a slow app stalls whatever
/// commits behind it (os-private-apis.md, #2531). Every read names
/// its call site, and one that took `slowThreshold` or longer
/// logs the site and the thread, which attributes a stalled
/// run-loop turn to the read that held it.
enum WindowListRead {
    /// Seconds; below the 100 ms run-loop stall the probe counts.
    static let slowThreshold: TimeInterval = 0.05

    /// Writes one `window-list read` line per slow read.
    nonisolated(unsafe) static var onSlow: (String) -> Void =
        CoreLog.write

    static func copy(
        _ site: String,
        _ options: CGWindowListOption,
        relativeTo window: CGWindowID = kCGNullWindowID
    ) -> [[String: Any]]? {
        let clock = ContinuousClock()
        var list: [[String: Any]]?
        let took = clock.measure {
            list =
                CGWindowListCopyWindowInfo(options, window)
                as? [[String: Any]]
        }
        let elapsed =
            Double(took.components.seconds)
            + Double(took.components.attoseconds) / 1e18
        if elapsed >= slowThreshold {
            report(site: site, elapsed: elapsed)
        }
        return list
    }

    static func report(site: String, elapsed: TimeInterval) {
        let ms = Int((elapsed * 1000).rounded())
        let thread = Thread.isMainThread ? "main" : "off main"
        onSlow("window-list read \(site): \(ms) ms \(thread)")
    }
}
