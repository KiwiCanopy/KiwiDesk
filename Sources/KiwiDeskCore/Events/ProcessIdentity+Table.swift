import Darwin
import Foundation

/// The process table's one `sysctl` home: `runs` and the start
/// age read the same record.
extension ProcessIdentity {
    /// The kernel's record of `pid` and the size it filled, nil
    /// where the read itself failed.
    static func processRecord(
        _ pid: pid_t
    ) -> (info: kinfo_proc, size: Int)? {
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.size
        guard sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0) == 0
        else { return nil }
        return (info, size)
    }

    /// Seconds since the kernel started the process at `pid`, nil
    /// where the table has no record (#2478). The kernel's start,
    /// not LaunchServices' `launchDate`, which the activation arm
    /// reads: no XPC round trip on the arrival path (#1936). `now`
    /// is the caller's `wallClock`.
    static func startAge(of pid: pid_t, now: Date) -> TimeInterval? {
        guard let record = processRecord(pid), record.size > 0
        else { return nil }
        let start = record.info.kp_proc.p_starttime
        let started = Date(
            timeIntervalSince1970: TimeInterval(start.tv_sec)
                + TimeInterval(start.tv_usec) / 1_000_000
        )
        return now.timeIntervalSince(started)
    }
}
