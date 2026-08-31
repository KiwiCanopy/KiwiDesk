import KiwiDeskCore
import SwiftUI

/// Status row and profile warning views for SettingsHeaderBar.
/// Takes NO traffic-light inset: it sits below the lights, so
/// it keeps the bar's ordinary gutter and stays aligned with
/// the content column beneath.
extension SettingsHeaderBar {

    var showDivergence: Bool {
        model.profileDirty && !model.editingStoredProfile
    }

    func statusRow(_ text: String) -> some View {
        HStack(spacing: 6) {
            if showDivergence {
                Image(
                    systemName: "exclamationmark.triangle.fill"
                )
                .foregroundStyle(SettingsTheme.warningInk)
            }
            Text(text)
                .font(.caption)
                .foregroundStyle(
                    showDivergence
                        ? SettingsTheme.warningInk
                        : SettingsTheme.ink2
                )
            Spacer()
        }
    }

    func warningRow(_ warning: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.bubble")
                .foregroundStyle(SettingsTheme.warningInk)
            Text(warning)
                .font(.caption)
                .foregroundStyle(SettingsTheme.ink2)
            Spacer()
            Button {
                model.profileWarning = nil
            } label: {
                Image(systemName: "xmark.circle")
            }
            .buttonStyle(.borderless)
            .iconButtonAffordance(
                L("profile_header.dismiss", "Dismiss")
            )
        }
    }

    var statusText: String? {
        if model.editingStoredProfile {
            // Editing the loaded profile's own overrides DOES
            // hit the screen — saving re-applies it in place
            // (#209) — so the generic "won't switch" copy is
            // false for that one target.
            if let name = model.editingProfile,
                name == model.activeProfile
            {
                return L(
                    "profile_header.status.editing_loaded",
                    "Editing %1$@'s saved overrides — saving "
                        + "re-applies %1$@ with your changes.",
                    name
                )
            }
            return L(
                "profile_header.status.editing_stored",
                "Editing a saved profile — changes won't "
                    + "switch your layout."
            )
        }
        if model.activeStandard != nil {
            return L(
                "profile_header.status.built_in",
                "Built-in layout — save as a profile to "
                    + "make it yours."
            )
        }
        if model.profileDirty {
            return L(
                "profile_header.status.unsaved_monitor",
                "Unsaved monitor changes — update the "
                    + "profile to keep them."
            )
        }
        if model.activeProfile == nil {
            return L(
                "profile_header.status.no_match",
                "No profile matches this monitor setup."
            )
        }
        return nil
    }
}
