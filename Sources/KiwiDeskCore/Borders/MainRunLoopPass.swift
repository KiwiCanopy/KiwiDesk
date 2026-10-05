import CoreFoundation

/// Counts the main run loop's passes, each ending after Core
/// Animation's commit, which is when AppKit sends a window frame
/// it was handed in that pass (#1956). A SkyLight move issued in
/// the same pass reaches WindowServer first and is overwritten.
@MainActor
enum MainRunLoopPass {
    private static var count: UInt64 = 0
    private static var observer: CFRunLoopObserver?

    /// The current pass; the first read installs the counter.
    static func current() -> UInt64 {
        if observer == nil {
            install()
        }
        return count
    }

    private static func install() {
        // Ordered last among the before-waiting observers, so it
        // counts after Core Animation's commit has run. Not on exit:
        // a run that exits without waiting left AppKit's frame
        // unsent, and a move after it was lost (device 2026-10-05).
        let observer = CFRunLoopObserverCreateWithHandler(
            nil,
            CFRunLoopActivity.beforeWaiting.rawValue,
            true,
            CFIndex.max
        ) { _, _ in
            MainActor.assumeIsolated { count &+= 1 }
        }
        CFRunLoopAddObserver(CFRunLoopGetMain(), observer, .commonModes)
        self.observer = observer
    }
}
