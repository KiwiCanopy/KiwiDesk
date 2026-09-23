import KiwiDeskCore
import SwiftUI

/// Status row and profile warning views for SettingsHeaderBar.
/// Takes NO traffic-light inset: it sits below the lights, so
/// it keeps the bar's ordinary gutter and stays aligned with
/// the content column beneath.
extension SettingsHeaderBar {

    var showDivergence: Bool { model.liveDrift }

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

    /// A stored profile is selected (#1393): one line saying so,
    /// in the warnings' shape, with Load where the dismiss sits.
    /// What a save changes is said per change in the save pill.
    func notLoadedRow(_ name: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
                .foregroundStyle(SettingsTheme.ink2)
                .accessibilityHidden(true)
            Text(
                L("profile_header.not_loaded", "%1$@ isn't loaded.", name)
            )
            .font(.caption)
            .foregroundStyle(SettingsTheme.ink2)
            Spacer()
            ProfileLoadButton(model: model, name: name, controlSize: .small)
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
        // A stored target says so on its own line (#1393).
        if model.editingStoredProfile { return nil }
        // The drift arms read the ONE verdict the pill's rows
        // read (#1197): a deleted match used to say "update the
        // profile" here with no profile to update.
        switch model.profileDrift {
        case .builtIn:
            return L(
                "profile_header.status.built_in",
                "Built-in layout — save as a profile to "
                    + "make it yours."
            )
        case .screensUnsaved:
            // A screen-count mismatch is the one drift Save
            // cannot take up (the hint that greys it says so),
            // so the line names the button that can (#818).
            if model.updateHint != nil {
                return L(
                    "profile_header.status.unsaved_monitor_count",
                    "Unsaved monitor changes — this profile is "
                        + "for another screen count; %1$@ to "
                        + "keep them.",
                    L(
                        "footer.save_as_new_profile",
                        "Save as New Profile…"
                    )
                )
            }
            return L(
                "profile_header.status.unsaved_monitor",
                "Unsaved monitor changes — update the "
                    + "profile to keep them."
            )
        case .noMatch:
            return L(
                "profile_header.status.no_match",
                "No profile matches this monitor setup."
            )
        case nil:
            break
        }
        if model.activeStandard != nil {
            return L(
                "profile_header.status.built_in",
                "Built-in layout — save as a profile to "
                    + "make it yours."
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
