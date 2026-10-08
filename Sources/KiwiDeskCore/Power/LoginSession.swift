import Darwin

/// The login session's identity (#1385): the audit session id
/// macOS mints per login, read with the public `getaudit_addr`. A
/// `WindowID` is only meaningful within one login, so a snapshot
/// written under another one replays ids the new login reuses.
///
/// Verified 2026-10-07, macOS 27.0: `getaudit_addr`'s id equalled
/// Security's `SessionGetInfo` and `launchctl print gui/501`'s
/// `asid` (100019); a terminal process and a transient
/// `launchctl submit` job (ppid 1) read the same, gui/501 being
/// the domain KiwiDesk's LaunchAgent and the login item
/// run in; the Background `user/501` domain carried another
/// (100046). That a logout and login mints a new one is from
/// audit(4) and launchd's per-session domains, not measured: a
/// logout ends the session that would read it. The ids restart
/// per boot, so this gate does not replace the boot gate (#633).
enum LoginSession {
    /// This process's audit session id, or nil when unreadable.
    static func current() -> Int32? {
        var info = auditinfo_addr()
        let size = Int32(MemoryLayout<auditinfo_addr>.size)
        guard getaudit_addr(&info, size) == 0 else { return nil }
        return info.ai_asid
    }
}
