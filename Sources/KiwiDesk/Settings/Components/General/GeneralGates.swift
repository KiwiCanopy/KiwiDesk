import KiwiDeskCore

/// Resolves the General area's declared census gates (#678 turn
/// 14b).
///
/// Same shape as `LayoutDefaultsGates` — keyed on a row's own
/// `SettingKey`, returning a REASON case rather than a Bool —
/// which is deliberate rather than incidental. `gui.md` asks that
/// the resolvers converge before a fourth shape appears, and the
/// reason case is the one shape that keeps a row's grey and the
/// sentence explaining it from being two decisions that can
/// disagree (item 19: why-you-cannot is always inline). What
/// differs per area is the CONTEXT it reads, not the signature.
///
/// This area reads `AutoStartStatus` where Layout Defaults reads
/// `TilingSettings`. Both gates here would have been
/// unanswerable a commit ago, when the status lived in
/// `LoginItemCard`'s `@State` — resolving them would have meant
/// re-implementing each predicate beside its control, which is
/// exactly what `gui.md` forbids and what would have forced both
/// to be declared "resolved elsewhere". Lifting the status is
/// what made this file possible.
///
/// Fail-OPEN on a gate this type does not own — loud in debug,
/// live in release — matching `BarsGates`,
/// `ShortcutsGates` and `LayoutDefaultsGates`. Of the two
/// silent readings, a live row the user can ignore beats a dead
/// one they cannot explain.
struct GeneralGates {
    let autoStart: AutoStartStatus

    /// Why a row is inert. One case per predicate; the sentence
    /// lives with the renderer, which keeps the whole resolver
    /// assertable off the main actor.
    enum InertReason: Hashable {
        /// The `kiwidesk service` LaunchAgent is loaded, so it
        /// already launches KiwiDesk at login and supervises it.
        /// The login item would only add a second launcher.
        case managedByService

        /// This copy cannot register a login item at all — a bare
        /// binary or a translocated download, neither of which
        /// has the stable `.app` path `SMAppService` needs. Carries
        /// the cause so the caption names the right fix (move to
        /// Applications vs run the packaged app), which the two
        /// rows would otherwise re-split inline.
        case cannotRegister(LoginItemUnavailable)
    }

    /// Why `key`'s row is inert right now, or nil while it is
    /// live.
    func inertReason(for key: SettingKey) -> InertReason? {
        guard key.placement.gate != nil else { return nil }
        switch key {
        case .general(.startAtLogin):
            // Order matters, as it does one case down: a copy
            // that cannot register at all is the harder stop,
            // and naming the service there would offer a fix
            // that would not work either.
            if let cause = autoStart.unavailable {
                return .cannotRegister(cause)
            }
            // The service starts KiwiDesk at login by itself
            // (`RunAtLoad`), so the login item would be a second
            // launcher racing the first (#1071). The switch says
            // what is true — KiwiDesk does start at login — and
            // stops being editable, because the answer is the
            // service's to give.
            return autoStart.level == .atLoginWithAutoRestart
                ? .managedByService : nil
        default:
            assertionFailure(
                "unhandled General gate: \(key.id)"
            )
            return nil
        }
    }

    /// The gated rows this resolver answers. Data, so the guard
    /// asserts the split against the census rather than restating
    /// it — a new gated row in this area lands in neither set and
    /// reds.
    static let resolved: Set<SettingKey> = [
        .general(.startAtLogin)
    ]

    /// Gated rows the area declares but resolves elsewhere. Empty,
    /// and kept as a declared slot rather than dropped: its
    /// absence is what would make a future unanswerable gate look
    /// like an omission instead of a decision.
    static let resolvedElsewhere: Set<SettingKey> = []
}
