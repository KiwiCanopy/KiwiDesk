import KiwiDeskCore
import SwiftUI

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
        .neutralMenuLabel()
        .fixedSize()
        // The closed menu shows only its VALUE (the profile's
        // name), so VoiceOver heard a name with no noun; the
        // pair below names the control and keeps the value
        // (#812, the App Rules facet shape).
        .accessibilityLabel(
            L("profile_header.menu.ax", "Profile to edit")
        )
        .accessibilityValue(title)
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
