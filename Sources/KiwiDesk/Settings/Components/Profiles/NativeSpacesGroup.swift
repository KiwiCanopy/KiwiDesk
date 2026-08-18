import KiwiDeskCore
import SwiftUI

/// Whole App ▸ Profiles ▸ **Profiles per macOS Desktop** (#7,
/// rebuilt in #678 turn 13a): bind a saved profile to each macOS
/// Desktop, picked from the row's dropdown; the binding emits
/// `bind_profile_to_native_space` — a wire name #768 deliberately
/// froze — and loads that profile when the Desktop activates on
/// the main display (#888, the definition that made the rows
/// well-defined under "Displays have separate Spaces" and
/// retired that state's grey, warning and escape hatch).
/// Rows are named "Desktop n", the name Mission Control shows,
/// never "Space n", which is how KiwiDesk's own Spaces read
/// elsewhere in the app. Bindings mutate
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
/// The remaining grey is the resolver's (`ProfilesGates`) and is
/// scoped to the ROWS: the explanation stays live under it. That
/// is also why the gate is not wrapped around the whole card
/// (#527): the drawer keeps its header and its `?` anchor
/// clickable.
struct NativeSpacesGroup: View {
    @ObservedObject var model: SettingsModel
    /// Drawn open (#678 turn 13a). View state, like every other
    /// drawer in the tree — per-container disclosure memory
    /// arrives with the mode mechanics.
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
            SettingsCatalog.profiles.nativeSpaces,
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
        }
    }

    private var intro: String {
        L(
            "native_spaces.intro",
            "These are your Mac's own Desktops, from Mission "
                + "Control — not KiwiDesk's Spaces. Pick a "
                + "profile to load automatically when a "
                + "Desktop activates on your main display "
                + "(the screen with the menu bar)."
        )
    }

    // #888 retired the inline warning note along with the
    // separate-Spaces grey. The one reason left
    // (`bindingsAreGlobal`) has its cause on the surface — the
    // header chip names the profile being edited — so by the
    // #815 derivation (`GateReasonPlacement`) these rows owe no
    // inline sentence, exactly like `presetsApply` under the
    // same reason; the `GreyOut`'s hover help still carries it.
    // The "Clear all bindings" escape hatch retired with the
    // grey too: with the rows live, each binding is cleared on
    // its own row, so the hatch lost the trap it existed to
    // open — `docs/design-decisions.md` re-argues the ruling.

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
