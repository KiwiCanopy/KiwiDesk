import CoreFoundation

/// The scroll tap's re-armable deadline (#1656): fires `fire` on
/// the run loop it was added to at each date `arm(at:)` sets.
///
/// Built REPEATING and re-dated rather than one-shot: CFRunLoop
/// invalidates a one-shot timer after its first callout, and a
/// dead timer ignores `SetNextFireDate` — so every gesture after
/// the first would never end (`ScrollExpiryTimerTests`).
final class ScrollExpiryTimer {
    /// Far enough out never to fire on its own between re-arms.
    private static let idle = 1e9
    private var timer: CFRunLoopTimer?

    init(on runLoop: CFRunLoop, fire: @escaping () -> Void) {
        let timer = CFRunLoopTimerCreateWithHandler(
            nil,
            CFAbsoluteTimeGetCurrent() + Self.idle,
            Self.idle,
            0,
            0
        ) { _ in fire() }
        CFRunLoopAddTimer(runLoop, timer, .commonModes)
        self.timer = timer
    }

    /// Fires at `date`, or never with nil.
    func arm(at date: Double?) {
        guard let timer else { return }
        CFRunLoopTimerSetNextFireDate(
            timer,
            date ?? CFAbsoluteTimeGetCurrent() + Self.idle
        )
    }

    func invalidate() {
        if let timer { CFRunLoopTimerInvalidate(timer) }
        timer = nil
    }
}
