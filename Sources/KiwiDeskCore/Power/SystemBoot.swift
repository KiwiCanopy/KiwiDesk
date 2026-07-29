import Foundation

/// The moment the machine booted, via the `kern.boottime`
/// sysctl.
///
/// Feeds the snapshot staleness gate (#633): a `WindowID` is
/// only meaningful within one boot — WindowServer mints fresh
/// low-integer `CGWindowID`s per login session, so a snapshot
/// captured before the current boot describes windows that no
/// longer exist, under ids the new session will recycle onto
/// unrelated windows.
enum SystemBoot {
    /// Boot time, or `.distantPast` when the sysctl fails.
    /// Failing open (every snapshot counts as same-boot) keeps
    /// restore working if the call ever breaks — the gate is a
    /// hardening, not a load-bearing feature. `kern.boottime`
    /// is wall-clock and moves under NTP steps, like the
    /// `capturedAt` stamps it is compared against: a forward
    /// step can wrongly discard a same-boot snapshot (benign —
    /// fresh rediscovery), a backward step can wrongly admit a
    /// pre-boot one (the pre-gate status quo, for the one
    /// launch after a manual clock change). Both accepted —
    /// see docs/accepted-limitations.md.
    static func time() -> Date {
        var tv = timeval()
        var size = MemoryLayout<timeval>.size
        guard
            sysctlbyname(
                "kern.boottime",
                &tv,
                &size,
                nil,
                0
            ) == 0,
            tv.tv_sec > 0
        else { return .distantPast }
        return Date(
            timeIntervalSince1970: TimeInterval(tv.tv_sec)
        )
    }
}
