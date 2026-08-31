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
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(SettingsTheme.warningInk)
            Text(
                L(
                    "settings.permission_paused",
                    "Window management is paused — KiwiDesk "
                        + "needs Accessibility permission."
                )
            )
            .font(.callout)
            .foregroundStyle(SettingsTheme.warningInk)
            .frame(maxWidth: .infinity, alignment: .leading)
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
        .padding(12)
        // A solid warning surface, never an opacity wash: a wash
        // takes its result from whatever is behind it, drifts with
        // the page, and cannot promise 4.5:1 for `warningInk`.
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(SettingsTheme.warningSurface)
        )
    }
}
