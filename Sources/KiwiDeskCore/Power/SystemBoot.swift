import Foundation

/// System boot timestamp query via sysctl `kern.boottime`
/// (#633): a `WindowID` is only meaningful within one boot — a
/// new login session recycles low-integer ids onto unrelated
/// windows.
enum SystemBoot {
    /// Boot time, or `.distantPast` on sysctl failure — failing
    /// OPEN keeps restore working; the gate is hardening. NTP
    /// steps can mis-gate either way, accepted in
    /// docs/accepted-limitations.md.
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
