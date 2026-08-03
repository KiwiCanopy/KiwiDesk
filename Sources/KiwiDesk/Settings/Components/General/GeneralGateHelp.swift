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
        case .cannotRegister:
            // The exact English the card already authors for
            // this key — `extract-keys` fails loudly when one key
            // carries two strings, rather than picking one.
            return L(
                "general.login_item.unavailable",
                "Move KiwiDesk to your Applications folder "
                    + "to turn this on."
            )
        case .loginOff:
            return L(
                "general.advanced.restart_on_crash.needs_login",
                "Needs “Start KiwiDesk when I log in”, because "
                    + "the two are one setting to macOS."
            )
        }
    }
}
