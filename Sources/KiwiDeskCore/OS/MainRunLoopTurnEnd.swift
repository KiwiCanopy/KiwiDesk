import CoreFoundation

/// Runs work once at the end of the current main run loop turn,
/// ahead of Core Animation's commit, so an order it issues lands
/// in that turn's commit (#2659). `MainRunLoopPass` is its
/// opposite: it counts AFTER the commit, and never on exit.
@MainActor
enum MainRunLoopTurnEnd {
    private static var pending: [@MainActor () -> Void] = []
    private static var observer: CFRunLoopObserver?

    /// Queues `work` for this turn's end; the first call installs
    /// the observer.
    static func schedule(_ work: @escaping @MainActor () -> Void) {
        if observer == nil {
            install()
        }
        pending.append(work)
    }

    private static func install() {
        // Order 0 runs before Core Animation's commit observer.
        // On exit too: a nested run that never waits still ends.
        let activities =
            CFRunLoopActivity.beforeWaiting.rawValue
            | CFRunLoopActivity.exit.rawValue
        let observer = CFRunLoopObserverCreateWithHandler(
            nil,
            activities,
            true,
            0
        ) { _, _ in
            MainActor.assumeIsolated { drain() }
        }
        CFRunLoopAddObserver(CFRunLoopGetMain(), observer, .commonModes)
        self.observer = observer
    }

    private static func drain() {
        while !pending.isEmpty {
            let work = pending
            pending = []
            for run in work { run() }
        }
    }
}
