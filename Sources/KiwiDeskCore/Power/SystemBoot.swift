import Foundation

/// System boot timestamp query via sysctl `kern.boottime` (#633).
enum SystemBoot {
    /// Returns machine boot time or `.distantPast` on sysctl failure (#633).
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
