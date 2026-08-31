import KiwiDeskCore
import SwiftUI

/// Localized explanation rendering for general settings gate reasons (#96).
@MainActor
enum GeneralGateHelp {
    static func sentence(
        for reason: GeneralGates.InertReason
    ) -> String {
        switch reason {
        case .cannotRegister(.translocated):
            return L(
                "general.login_item.unavailable",
                "Move KiwiDesk to your Applications folder "
                    + "to turn this on."
            )
        case .cannotRegister(.notBundled):
            return L(
                "general.login_item.unavailable_binary",
                "Available only when running the KiwiDesk app."
            )
        case .managedByService:
            // Gated so only someone who already used the CLI sees
            // it (#1071). The command is an ARGUMENT, not prose:
            // written into the sentence, `service`/`stop` are
            // words a translator translates — `english_residue`
            // proved a correct translation would be DISCARDED by
            // `merge-keys`, while a translated one yields a
            // command that does not exist. The switch's label is
            // interpolated per #818.
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
