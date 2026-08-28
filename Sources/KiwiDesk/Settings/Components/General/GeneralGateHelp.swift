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
            return L(
                "general.login_item.managed_by_service",
                "KiwiDesk starts at login as a service, which "
                    + "also restarts it if it stops "
                    + "unexpectedly. Run “kiwidesk service "
                    + "stop” to manage it here instead."
            )
        }
    }
}
