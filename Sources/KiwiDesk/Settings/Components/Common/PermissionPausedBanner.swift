import KiwiDeskCore
import SwiftUI

/// Warning banner displayed when macOS Accessibility permission
/// is missing. Non-dismissible (hiding "nothing works" while true
/// is a grey-don't-hide violation), and the rows below stay
/// EDITABLE — the banner says "paused" rather than greying the
/// dashboard, so a setup prepared before the grant is waiting the
/// moment it lands.
struct PermissionPausedBanner: View {
    /// Action opening macOS System Settings (`AppDelegate`, #678 Phase 4).
    let onResolve: () -> Void

    var body: some View {
        WarningBox(
            text: L(
                "settings.permission_paused",
                "Window management is paused — KiwiDesk "
                    + "needs Accessibility permission."
            )
        ) {
            // ONE key with the onboarding button, not a twin
            // (l10n audit 2026-08-11): `onboarding.grant.body`
            // QUOTES this label in its steps. Renamed out of
            // `onboarding.` because this banner outlives it.
            Button(
                L(
                    "common.open_system_settings",
                    "Open System Settings"
                )
            ) {
                onResolve()
            }
            .settingsActionButton()
        }
    }
}
