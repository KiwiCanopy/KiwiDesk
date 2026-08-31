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
            // Command string and control label are interpolated (#818, #1071).
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
