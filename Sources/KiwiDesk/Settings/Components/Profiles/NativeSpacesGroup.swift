import KiwiDeskCore
import SwiftUI

/// Whole App ▸ Profiles ▸ **Profiles per macOS Space** (#7,
/// rebuilt in #678 turn 13a): bind a saved profile to each native
/// macOS Space, picked from the row's dropdown; the binding emits
/// `bind_profile_to_native_space` and loads that profile when the
/// Space activates. Rows are named "Desktop n" — the name Mission
/// Control shows — never "Space n", which is how KiwiDesk's own
/// virtual spaces read elsewhere in the app. Bindings mutate
/// `model.config.profileBindings`; the footer's profile actions
/// persist them.
///
/// A drawer now, because the census tiers `profileBindings`
/// `.showMore` — most people never bind a Desktop, and the ones
/// who do are looking for it. It opens by default all the same:
/// the card is one interaction deep, not hidden, and a reader who
/// scrolled to it has already asked the question its title
/// answers.
///
/// Both greys are the resolver's (`ProfilesGates`), and both are
/// scoped to the ROWS: the explanation and its "Open Desktop &
/// Dock" button stay live under a grey, since the advice holds —
/// and the button works — in exactly the state that dims the
/// rows. That is also why the gate is not wrapped around the
/// whole card (#527): the drawer keeps its header and its `?`
/// anchor clickable.
struct NativeSpacesGroup: View {
    @ObservedObject var model: SettingsModel
    /// Drawn open (#678 turn 13a). View state, like every other
    /// drawer in the tree — per-container disclosure memory
    /// arrives with the mode mechanics.
    @State private var expanded = true

    private var gates: ProfilesGates {
        ProfilesGates(
            editingStoredProfile: model.editingStoredProfile,
            separateDisplaySpaces:
                model.displaysHaveSeparateSpaces,
            connectedScreens: model.displays.count
        )
    }

    var body: some View {
        let reason = gates.inertReason(
            for: .profiles(.profileBindings)
        )
        SettingsDisclosure(
            SettingsCatalog.profiles.nativeSpaces,
            chrome: .card,
            isExpanded: $expanded
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Text(intro)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let reason {
                    inertNote(reason)
                }
                rows(inert: reason)
            }
            .padding(.top, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var intro: String {
        L(
            "native_spaces.intro",
            "Each Desktop is a native macOS Space from "
                + "Mission Control. Pick a profile to load "
                + "it automatically when that Desktop "
                + "activates."
        )
    }

    /// Why the rows are dead, inline — why-you-cannot is never a
    /// tooltip alone (VoiceOver reads it) — and, for the reason
    /// that has one, the fix.
    ///
    /// **The escape hatch is load-bearing, not a convenience.**
    /// Greying every row takes away the only control that can
    /// CLEAR a binding, while Core keeps firing bound profiles
    /// regardless of the OS setting (`applyNativeSpaceBinding`
    /// consults no display-Spaces state). Without this button a
    /// user who bound a Desktop *before* turning separate Spaces
    /// on is stuck with a binding that fires and cannot be
    /// removed short of a log out — the grey would have created
    /// the trap it exists to prevent. So the note stays outside
    /// the `GreyOut` and carries both the way out of the OS
    /// setting and the way out of the bindings.
    private func inertNote(
        _ reason: ProfilesGates.InertReason
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(SettingsTheme.warningInk)
            VStack(alignment: .leading, spacing: 8) {
                Text(ProfilesGateHelp.sentence(for: reason))
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                if reason == .desktopsAreAmbiguous {
                    ambiguityActions
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(SettingsTheme.warningSurface)
        )
    }

    private var ambiguityActions: some View {
        HStack(spacing: 8) {
            Button(
                L(
                    "native_spaces.open_settings",
                    "Open Desktop & Dock"
                )
            ) {
                DisplaySpacesSetting.openSystemSettings()
            }
            .buttonStyle(.bordered)
            .neutralButtonLabel()
            .controlSize(.large)
            // Absent, not greyed, with nothing to clear: an
            // affordance for a channel that does not exist reads
            // as broken rather than as forthcoming (gui.md), and
            // here "no bindings" is the state the grey is
            // harmless in.
            if !model.config.profileBindings.isEmpty {
                Button(
                    L(
                        "native_spaces.clear_all",
                        "Clear all bindings"
                    ),
                    role: .destructive
                ) {
                    model.clearProfileBindings()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .help(
                    L(
                        "native_spaces.clear_all.help",
                        "Removes every Desktop → profile "
                            + "binding. The footer's Save writes "
                            + "it."
                    )
                )
            }
        }
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
                "native_spaces.empty",
                "No native macOS Desktops detected. Add "
                    + "desktops in Mission Control to bind "
                    + "profiles."
            )
        )
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    // MARK: - Rows

    private func spaceRow(_ number: Int) -> some View {
        HStack {
            Image(systemName: "square.on.square")
                .foregroundStyle(.secondary)
            Text(
                L(
                    "native_spaces.desktop",
                    "Desktop %1$d",
                    number
                )
            )
            .fontWeight(.medium)
            if number == model.currentNativeSpace {
                BadgeChip(
                    label: L("native_spaces.current", "current")
                )
            }
            Spacer()
            profileMenu(number)
        }
    }

    private func profileMenu(_ number: Int) -> some View {
        Picker("", selection: binding(number)) {
            Text(L("native_spaces.none", "None"))
                .tag(String?.none)
            ForEach(options(number), id: \.self) { name in
                Text(name).tag(String?.some(name))
            }
        }
        .labelsHidden()
        .controlSize(.large)
        .frame(width: 180)
    }

    // MARK: - Data

    /// Native Spaces to list — from the family seam that records
    /// what this census key expands to, so the guard over that
    /// expansion watches the rows the card actually draws.
    private var spaceNumbers: [Int] {
        ProfilesFamilyRows.desktops(
            present: model.nativeSpaceCount,
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
