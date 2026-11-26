import Foundation

extension KeyboardTap {
    /// Seconds on the tap's clock.
    typealias Clock = @Sendable () -> TimeInterval
    /// Runs the work once the delay, in seconds, has passed.
    typealias Lapse =
        @Sendable (TimeInterval, @escaping @Sendable () -> Void) -> Void

    /// The live tap's clock: uptime in seconds, since
    /// `CGEvent.timestamp`'s unit differs by architecture (mach
    /// ticks on arm64).
    static let liveClock: Clock = {
        TimeInterval(clock_gettime_nsec_np(CLOCK_UPTIME_RAW)) / 1e9
    }

    /// The live tap's lapse, on a global queue off the tap thread.
    static let liveLapse: Lapse = { delay, work in
        DispatchQueue.global(qos: .userInteractive).asyncAfter(
            deadline: .now() + delay,
            execute: work
        )
    }
}
