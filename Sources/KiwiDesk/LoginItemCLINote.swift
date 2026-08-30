import KiwiDeskCore

/// Formats login-item status notes for `kiwidesk service` CLI output
/// (#96, #196, #575).
enum LoginItemCLINote {
    /// Status line appended to `service status`.
    static func statusLine(_ state: LoginItemState) -> String {
        switch state {
        case .enabled:
            return "login item: on (opens at login via "
                + "Settings \u{25B8} General)"
        case .requiresApproval:
            return "login item: awaiting approval in System "
                + "Settings \u{25B8} Login Items"
        case .notRegistered:
            return "login item: off"
        case .unavailable:
            return "login item: not applicable from this binary"
        }
    }

    /// Note appended after `service start` when login item is also enabled.
    static func startNote(_ state: LoginItemState) -> String? {
        guard state == .enabled else { return nil }
        return "Note: KiwiDesk is also set to open at login "
            + "(Settings \u{25B8} General), so two mechanisms "
            + "will start it. They never fight over your "
            + "windows \u{2014} the instance lock keeps that to "
            + "one process \u{2014} but only the launch that "
            + "wins is supervised. Run one: turn off Start at "
            + "login, or `kiwidesk service stop`."
    }
}
