import KiwiDeskCore
import SwiftUI

/// Settings group for binding profiles to macOS Desktops (#7, #678, #768,
/// #888).
struct DesktopsGroup: View {
    @ObservedObject var model: SettingsModel
    @State private var expanded = true

    private var gates: ProfilesGates {
        ProfilesGates(
            editingStoredProfile: model.editingStoredProfile,
            connectedScreens: model.displays.count
        )
    }

    var body: some View {
        let reason = gates.inertReason(
            for: .profiles(.profileBindings)
        )
        SettingsDisclosure(
            SettingsCatalog.profiles.desktops,
            chrome: .card,
            isExpanded: $expanded
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Text(intro)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                rows(inert: reason)
            }
            .padding(.top, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
        } accessory: {
            HelpButton(
                explanation: helpText,
                subject: L(
                    "desktops.title",
                    "Profiles per macOS Desktop"
                )
            )
        }
    }

    /// Help explanation for main screen Desktop binding behavior (#888).
    private var helpText: String {
        L(
            "desktops.help",
            "Only Desktops on your main screen can be bound, "
                + "because macOS's \"Displays have separate "
                + "Spaces\" gives every screen its own Desktops "
                + "by default. Turn it off, in System Settings ▸ "
                + "Desktop & Dock, and every Desktop is shared "
                + "across your screens instead — all of them "
                + "bindable, at the cost of each screen's own "
                + "menu bar, its own Dock, and fullscreen windows "
                + "that no longer blank the others."
        )
    }

    private var intro: String {
        L(
            "desktops.intro",
            "These are your Mac's own Desktops, from Mission "
                + "Control — not KiwiDesk's Spaces. Pick a "
                + "profile to load automatically when a "
                + "Desktop activates on your main screen "
                + "(the one with the menu bar)."
        )
    }

    @ViewBuilder private func rows(
        inert reason: ProfilesGates.InertReason?
    ) -> some View {
        let help =
            reason.map(ProfilesGateHelp.sentence) ?? ""
        Group {
            if spaceNumbers.isEmpty {
                emptyHint
            } else {
                ForEach(spaceNumbers, id: \.self) { number in
                    spaceRow(number)
                }
            }
        }
        .modifier(
            GreyOut(active: reason != nil, help: help)
        )
    }

    private var emptyHint: some View {
        Text(
            L(
                "desktops.empty",
                "No native macOS Desktops detected. Add "
                    + "Desktops in Mission Control to bind "
                    + "profiles."
            )
        )
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    // MARK: - Rows

    private func spaceRow(_ number: Int) -> some View {
        HStack {
            Image(systemName: DesktopGlyph.symbol)
                .foregroundStyle(.secondary)
            Text(
                L(
                    "desktops.desktop",
                    "Desktop %1$d",
                    number
                )
            )
            .fontWeight(.medium)
            if number == model.currentDesktop {
                BadgeChip(
                    label: L("desktops.current", "current")
                )
            }
            // A Desktop that is bound but does NOT live on the
            // main screen: listed because it carries the user's
            // own configuration, badged because a binding there
            // cannot fire in this arrangement — it waits for a
            // display change that makes that Desktop the main
            // screen's.
            //
            // A badge, never a grey: this row's picker is the
            // only way to change or clear that binding, so
            // dimming it would be the trap
            // `docs/design-decisions.md` bans — and the store is
            // valid and already effective, which "grey, don't
            // hide" does not describe (ui-designer, 2026-08-18).
            if !model.mainDesktops.contains(number) {
                BadgeChip(
                    label: L(
                        "desktops.not_on_main",
                        "not on main screen"
                    )
                )
            }
            Spacer()
            profileMenu(number)
        }
    }

    private func profileMenu(_ number: Int) -> some View {
        Picker("", selection: binding(number)) {
            Text(L("desktops.none", "None"))
                .tag(String?.none)
            ForEach(options(number), id: \.self) { name in
                Text(name).tag(String?.some(name))
            }
        }
        .labelsHidden()
        .controlSize(.large)
        .frame(width: 180)
        .accessibilityLabel(
            L(
                "desktops.profile_ax",
                "Profile for this Desktop"
            )
        )
        .accessibilityValue(
            binding(number).wrappedValue
                ?? L("desktops.none", "None")
        )
    }

    /// Desktops to list from `ProfilesFamilyRows.desktops`.
    private var spaceNumbers: [Int] {
        ProfilesFamilyRows.desktops(
            onMain: model.mainDesktops,
            bound: model.config.profileBindings.keys
        )
    }

    /// Available profiles for the dropdown, always including the
    /// current binding even if its file has since been deleted.
    private func options(_ number: Int) -> [String] {
        var names = model.profiles
        if let bound = model.config.profileBindings[number],
            !names.contains(bound)
        {
            names.append(bound)
        }
        return names
    }

    private func binding(_ number: Int) -> Binding<String?> {
        Binding(
            get: { model.config.profileBindings[number] },
            set: { model.config.profileBindings[number] = $0 }
        )
    }
}
