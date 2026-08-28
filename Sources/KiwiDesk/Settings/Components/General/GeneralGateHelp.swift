import KiwiDeskCore
import SwiftUI

/// The sentence each `GeneralGates.InertReason` renders.
///
/// Split from the resolver for the reason `LayoutDefaultsGateHelp`
/// is: the reason is a CASE, so the resolver stays assertable off
/// the main actor, and only this half needs `L()` — which is
/// `@MainActor`. It is the #96 seam applied inside the GUI.
@MainActor
enum GeneralGateHelp {
    static func sentence(
        for reason: GeneralGates.InertReason
    ) -> String {
        switch reason {
        case .cannotRegister(.translocated):
            // A read-only translocated copy — the fix is to move it
            // out of quarantine into Applications.
            return L(
                "general.login_item.unavailable",
                "Move KiwiDesk to your Applications folder "
                    + "to turn this on."
            )
        case .cannotRegister(.notBundled):
            // A bare binary (the device-QA `.build/release` path) —
            // there is no `.app` to register, so the fix is to run
            // the packaged app.
            return L(
                "general.login_item.unavailable_binary",
                "Available only when running the KiwiDesk app."
            )
        case .managedByService:
            // The one place Settings names a terminal command,
            // and it is gated so that only someone who already
            // used the CLI can see it (#1071): the service is
            // reachable no other way, so this answers the person
            // who turned it on rather than advertising it.
            //
            // **The command is an ARGUMENT, not prose.** Written
            // into the sentence it is three ordinary English
            // words — `service` and `stop` are exactly what a
            // translator translates — and `english_residue`
            // proved it both ways: it flags them as untranslated
            // residue in every non-Latin locale, so a correct
            // translation would be DISCARDED by `merge-keys`,
            // while a translated one yields a command that does
            // not exist. As a specifier it is stripped before
            // the residue check and never reaches the catalog.
            // The switch's own label is interpolated for the
            // same reason #818 gives: naming a control means
            // interpolating its key, never quoting it.
            return L(
                "general.login_item.managed_by_service",
                "KiwiDesk starts at login as a service, which "
                    + "also restarts it if it stops "
                    + "unexpectedly. Run “%1$@” to use “%2$@” "
                    + "instead.",
                "kiwidesk service stop",
                L("general.login_item.start", "Start at login")
            )
        }
    }
}
