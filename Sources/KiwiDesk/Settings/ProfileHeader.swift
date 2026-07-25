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
            .iconButtonAffordance(
                L("profile_header.dismiss", "Dismiss")
            )
        }
    }

    private var statusText: String? {
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

/// The profile edit-target dropdown (#18): pick the live config
/// or a saved profile to edit in place — editing a non-loaded
/// profile never switches the running layout. A borderless menu
/// (title + chevron, no pill). Saving lives in the footer.
struct ProfileEditTargetMenu: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        // The menu isn't an icon-only control, so its "why"
        // rides a label-adjacent `?` popover (#94/#259), not a
        // hover-only `.help()` a user finds by accident. One `?`
        // in this shared header → subject omitted (#251). The
        // live `statusText` caption still carries the dynamic
        // per-target state beneath.
        HStack(spacing: 4) {
            menu
            HelpButton(
                explanation: L(
                    "profile_header.menu.help",
                    "Pick a saved profile to edit — editing it "
                        + "won't switch your layout."
                )
            )
        }
    }

    private var menu: some View {
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
    }

    private func requestSelect(_ name: String?) {
        // A `nil` name is Live (`editingProfile == nil`); any
        // name — the loaded profile included (#209) — is that
        // stored target. Re-picking the open one is a no-op, so
        // it never pops a pointless discard dialog.
        guard name != model.editingProfile else { return }
        // This menu was the original discard-confirm site; it
        // now shares the dashboard-wide gate (#515) so the six
        // other discard paths cannot drift from it.
        model.discardingEdits(
            message: L(
                "discard.switch_profile.message",
                "Switching profiles drops the edits you "
                    + "haven't saved."
            ),
            confirmLabel: L(
                "discard.switch_profile.confirm",
                "Discard & switch"
            )
        ) { model.selectEditTarget(name) }
    }

    private var liveEntryLabel: String {
        let mark = model.editingProfile == nil ? "✓ " : ""
        if model.activeProfile != nil {
            return mark
                + L(
                    "profile_header.live.loaded",
                    "Live (currently loaded)"
                )
        }
        if let standard = model.activeStandard {
            return mark
                + L(
                    "profile_header.live.standard",
                    "Live — Standard: %1$@",
                    standardDisplayName(standard)
                )
        }
        return mark
            + L(
                "profile_header.live.transient",
                "Live — transient layout"
            )
    }

    private func menuRowLabel(_ name: String) -> String {
        let mark = model.editingProfile == name ? "✓ " : ""
        guard name == model.activeProfile else {
            return "\(mark)\(name)"
        }
        return mark
            + L(
                "profile_header.menu_row.loaded",
                "%1$@ (currently loaded)",
                name
            )
    }

    private var title: String {
        // Override mode gets a distinct closed-menu form, so
        // "MyProfile — overrides" can't be mistaken for Live
        // with MyProfile loaded — which shows the bare name and
        // would otherwise collide when editing the loaded
        // profile (#209).
        if let editing = model.editingProfile {
            return L(
                "profile_header.title.overrides",
                "%1$@ — overrides",
                editing
            )
        }
        if let profile = model.activeProfile { return profile }
        if let standard = model.activeStandard {
            return L(
                "profile_header.title.standard",
                "Standard: %1$@",
                standardDisplayName(standard)
            )
        }
        return L(
            "profile_header.title.transient",
            "Transient layout"
        )
    }
}
