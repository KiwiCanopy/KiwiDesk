import KiwiDeskCore
import SwiftUI

/// Settings group for binding profiles to macOS Desktops (#7,
/// #678, #768, #888). The remaining grey is the resolver's and is
/// scoped to the ROWS, not the whole card (#527: the drawer keeps
/// its header and `?` anchor clickable). By the #815 derivation
/// (`GateReasonPlacement`) these rows owe no inline sentence —
/// the `bindingsAreGlobal` cause is on the surface, exactly like
/// `presetsApply` under the same reason.
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

    /// Help explanation for the main-screen authority (#888,
    /// ui-designer 2026-08-18). Descriptive, never prescriptive —
    /// the retired shape was ambient advice with a one-click
    /// flip; the checkbox is quoted verbatim so System Settings'
    /// own search finds it (config-vocabulary.md's ask).
    private var helpText: String {
        L(
            "desktops.help",
            "Only a Desktop on your main screen selects a "
                + "profile, because macOS's \"Displays have "
                + "separate Spaces\" gives every screen its own "
                + "Desktops by default. Turn it off, in System "
                + "Settings ▸ Desktop & Dock, and every Desktop "
                + "is shared across your screens instead — all "
                + "of them able to select one, at the cost of "
                + "each screen's own menu bar, its own Dock, and "
                + "fullscreen windows that no longer blank the "
                + "others."
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
            //
            // A Desktop that is not there AT ALL — its screen
            // unplugged, or the Desktop deleted — is the same
            // ruling one step further: the record is kept
            // (absence is never proof it is gone), the row is
            // labelled with the number it was last seen at, and
            // the badge says why nothing will fire.
            if model.desktopKeys[number] == nil {
                BadgeChip(
                    label: L(
                        "desktops.absent",
                        "not present"
                    )
                )
            } else if !model.mainDesktops.contains(number) {
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
        // An empty title names nothing, so the picker is named
        // here — and named, it owes its selection back as the
        // value (#812).
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

    /// Desktops to list from `ProfilesFamilyRows.desktops`. A
    /// bound Desktop enters by its own last-seen NUMBER — the
    /// projection — since a key names no row a user could read.
    private var spaceNumbers: [Int] {
        ProfilesFamilyRows.desktops(
            onMain: model.mainDesktops,
            bound: model.config.profileBindings.values.map(
                \.desktop
            )
        )
    }

    /// The key the row's binding is filed under (#1147): the
    /// Desktop this number names right now, else the key an
    /// existing record already carries — a dormant Desktop's
    /// display is unplugged and the record must stay reachable —
    /// else the number itself, for a row about to be bound.
    private func key(_ number: Int) -> DesktopKey {
        if let live = model.desktopKeys[number] { return live }
        let dormant = model.config.profileBindings.first {
            $0.value.desktop == number
        }
        return dormant?.key ?? .number(number)
    }

    /// Available profiles for the dropdown, always including the
    /// current binding even if its file has since been deleted.
    private func options(_ number: Int) -> [String] {
        var names = model.profiles
        if let bound = model.config.profileBindings[key(number)]?
            .profile,
            !names.contains(bound)
        {
            names.append(bound)
        }
        return names
    }

    private func binding(_ number: Int) -> Binding<String?> {
        Binding(
            get: {
                model.config.profileBindings[key(number)]?.profile
            },
            set: { profile in
                let slot = key(number)
                guard let profile else {
                    model.config.profileBindings[slot] = nil
                    return
                }
                model.config.profileBindings[slot] = DesktopBinding(
                    profile: profile,
                    desktop: number,
                    display: model.config.profileBindings[slot]?
                        .display
                )
            }
        )
    }
}
