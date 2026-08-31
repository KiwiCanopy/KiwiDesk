import KiwiDeskCore
import SwiftUI

/// Profile edit-target dropdown menu (#18, #94, #251, #259).
struct ProfileEditTargetMenu: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
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
        .accessibilityLabel(
            L("profile_header.menu.ax", "Profile to edit")
        )
        .accessibilityValue(title)
    }

    private func requestSelect(_ name: String?) {
        guard name != model.editingProfile else { return }
        // Confirms discarding pending edits before switching profile
        // (#209, #515).
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
        // Override form distinguishes editing stored copy from loaded live
        // layout (#209).
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
