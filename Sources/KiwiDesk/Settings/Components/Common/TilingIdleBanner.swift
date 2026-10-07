import KiwiDeskCore
import SwiftUI

/// Banner shown while Accessibility is granted but Start Tiling
/// was never pressed (#2050). Neutral, not a warning: not tiling
/// yet is the user's choice. Non-dismissible while true, and the
/// rows below stay editable, as under `PermissionPausedBanner`.
struct TilingIdleBanner: View {
    let onStart: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "pause.circle")
                .foregroundStyle(SettingsTheme.ink2)
                .accessibilityHidden(true)
            Text(
                L(
                    "settings.tiling_idle",
                    "KiwiDesk isn't tiling yet — your windows stay "
                        + "where they are."
                )
            )
            .font(.callout)
            .foregroundStyle(SettingsTheme.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            Button(L("common.start_tiling", "Start Tiling")) {
                onStart()
            }
            .settingsActionButton()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(SettingsTheme.sunken)
        )
        // The neutral fill barely parts from the page ground, so
        // the edge carries the banner's shape.
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(SettingsTheme.hairline, lineWidth: 1)
        )
    }
}
