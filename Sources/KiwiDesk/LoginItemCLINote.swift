import KiwiDeskCore

/// The login-item awareness lines for `kiwidesk service` output
/// (#575). The `service` LaunchAgent and the `SMAppService` login
/// item are two independent auto-start paths that don't conflict
/// (the #196 single-instance lock dedupes them); these lines make
/// the overlap visible where a power user already is — the CLI.
///
/// English by the §5 machine-contract rule (CLI/IPC strings are the
/// sanctioned English exception, never localized). Core hands over
/// `LoginItemState` structure; the sentence is rendered here — the
/// #96 seam, on the CLI side. This lives in the CLI layer, not
/// `ServiceManager`, so the launchctl subsystem never learns about
/// `SMAppService` (the two Core subsystems stay decoupled).
enum LoginItemCLINote {
    /// The line appended to `service status`: always reports the
    /// login-item half of the full auto-start picture. Degrades to
    /// "not applicable" for a bare non-`.app` binary — where
    /// `SMAppService.mainApp` has no real registration to report —
    /// rather than printing a misleading state.
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

    /// The note appended after a successful `service start`, only
    /// when the login item is *also* on — a reassuring word that the
    /// two overlap safely. `nil` (silent) otherwise, so the common
    /// case stays clean.
    static func startNote(_ state: LoginItemState) -> String? {
        guard state == .enabled else { return nil }
        return "Note: KiwiDesk is also set to open at login "
            + "(Settings \u{25B8} General). The service adds "
            + "crash-restart supervision on top \u{2014} the two "
            + "don't conflict."
    }
}
