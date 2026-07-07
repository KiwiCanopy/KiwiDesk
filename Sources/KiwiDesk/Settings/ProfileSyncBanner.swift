import KiwiDeskCore
import SwiftUI

/// Top banner: a dropdown to pick which profile to edit (the
/// live/active config or any saved profile — #18), the
/// transient/dirty state, and profile-action warnings (#36).
/// Saving lives in the footer's profile buttons.
struct ProfileSyncBanner: View {
    @ObservedObject var model: SettingsModel
    @State private var confirmingSwitch = false
    @State private var switchTarget: String?

    private var showDivergence: Bool {
        model.profileDirty && !model.editingStoredProfile
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "rectangle.3.group")
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 1) {
                    profilePicker
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(
                            showDivergence ? .orange : .secondary
                        )
                }
                Spacer()
                if showDivergence {
                    Image(
                        systemName:
                            "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(.orange)
                    .help(
                        "The live layout diverged from the "
                            + "saved profile."
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            if let warning = model.profileWarning {
                warningRow(warning)
            }
        }
        .confirmationDialog(
            "Discard unsaved changes?",
            isPresented: $confirmingSwitch,
            titleVisibility: .visible
        ) {
            Button("Discard & switch", role: .destructive) {
                model.selectEditTarget(switchTarget)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "Switching profiles drops the edits you "
                    + "haven't saved."
            )
        }
    }

    /// The banner title doubles as a dropdown: pick any saved
    /// profile to edit it in place (Model A) — editing a
    /// non-loaded profile never switches the running layout (#18).
    private var profilePicker: some View {
        Menu {
            Button {
                requestSelect(nil)
            } label: {
                Text(liveEntryLabel)
            }
            if !model.profileSummaries.isEmpty {
                Divider()
                ForEach(model.profileSummaries) { summary in
                    Button {
                        requestSelect(summary.name)
                    } label: {
                        Text(menuRowLabel(summary.name))
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(title).font(.headline)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help(
            "Pick a saved profile to edit — editing it won't "
                + "switch your layout."
        )
    }

    private func requestSelect(_ name: String?) {
        if model.isDirty {
            switchTarget = name
            confirmingSwitch = true
        } else {
            model.selectEditTarget(name)
        }
    }

    private var liveEntryLabel: String {
        let mark = model.editingProfile == nil ? "✓ " : ""
        if model.activeProfile != nil {
            return "\(mark)Live (currently loaded)"
        }
        if let standard = model.activeStandard {
            return "\(mark)Live — Standard: \(standard)"
        }
        return "\(mark)Live — transient layout"
    }

    private func menuRowLabel(_ name: String) -> String {
        let mark = model.editingProfile == name ? "✓ " : ""
        let loaded =
            name == model.activeProfile
            ? " (currently loaded)" : ""
        return "\(mark)\(name)\(loaded)"
    }

    private var title: String {
        if let editing = model.editingProfile { return editing }
        if let profile = model.activeProfile { return profile }
        if let standard = model.activeStandard {
            return "Standard: \(standard)"
        }
        return "Transient layout"
    }

    private var statusText: String {
        if model.editingStoredProfile {
            return "Editing a saved profile — changes won't "
                + "switch your layout."
        }
        if model.activeStandard != nil {
            return "Built-in layout — save as a profile to "
                + "make it yours."
        }
        if model.profileDirty {
            return "Unsaved monitor changes — update the "
                + "profile to keep them."
        }
        return model.activeProfile == nil
            ? "No profile matches this monitor setup."
            : "Profile is up to date."
    }

    private func warningRow(_ warning: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.bubble")
                .foregroundStyle(.orange)
            Text(warning)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                model.profileWarning = nil
            } label: {
                Image(systemName: "xmark.circle")
            }
            .buttonStyle(.borderless)
            .help("Dismiss")
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}
