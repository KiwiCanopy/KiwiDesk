import KiwiDeskCore
import SwiftUI

/// Warning banner displayed when macOS Accessibility permission is missing.
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
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(SettingsTheme.warningSurface)
        )
    }
}
