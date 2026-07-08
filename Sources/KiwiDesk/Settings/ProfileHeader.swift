import KiwiDeskCore
import SwiftUI

/// The full-width settings header (#68): the section title and
/// the profile edit-target dropdown on one row, with the profile
/// status sentence beneath. A plain bar over `.bar` material —
/// the section content scrolls below it, no toolbar pills.
struct ProfileHeaderBar: View {
    @ObservedObject var model: SettingsModel
    let title: String
    let showsProfileContext: Bool

    private var showDivergence: Bool {
        model.profileDirty && !model.editingStoredProfile
    }

    @ViewBuilder var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.title2.weight(.bold))
            if showsProfileContext {
                ProfileEditTargetMenu(model: model)
                if let status = statusText {
                    statusRow(status)
                }
                if let warning = model.profileWarning {
                    warningRow(warning)
                }
            }
        }
        .padding(.horizontal, 16)
        // Clears the traffic-light row — `SettingsView`'s
        // `ignoresSafeArea(.top)` discards the titlebar inset
        // that would otherwise size this, so it's a fixed
        // constant matched to the unified-titlebar height. This
        // is the known-fragile point if Apple changes that
        // metric (a visual break the verify gate can't catch).
        .padding(.top, 32)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
        Divider()
    }

    private func statusRow(_ text: String) -> some View {
        HStack(spacing: 6) {
            if showDivergence {
                Image(
                    systemName: "exclamationmark.triangle.fill"
                )
                .foregroundStyle(.orange)
            }
            Text(text)
                .font(.caption)
                .foregroundStyle(
                    showDivergence ? .orange : .secondary
                )
            Spacer()
        }
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
    }

    private var statusText: String? {
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
        if model.activeProfile == nil {
            return "No profile matches this monitor setup."
        }
        return nil
    }
}

/// The profile edit-target dropdown (#18): pick the live config
/// or a saved profile to edit in place — editing a non-loaded
/// profile never switches the running layout. A borderless menu
/// (title + chevron, no pill). Saving lives in the footer.
struct ProfileEditTargetMenu: View {
    @ObservedObject var model: SettingsModel
    @State private var confirmingSwitch = false
    @State private var switchTarget: String?

    var body: some View {
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
            HStack(spacing: 5) {
                Image(systemName: "square.stack.3d.up")
                Text(title)
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

    private func requestSelect(_ name: String?) {
        // Resolve to the same target `selectEditTarget` will
        // use, so re-picking the open profile is a no-op that
        // never pops a pointless discard dialog.
        let target = (name == model.activeProfile) ? nil : name
        guard target != model.editingProfile else { return }
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
}
