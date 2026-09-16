import KiwiDeskCore
import SwiftUI

/// Settings group for binding profiles to macOS Desktops (#7,
/// #678, #768, #888). The rows are live under every edit target
/// — bindings are a global table, filed by a stored-profile Save
/// too — and inert only where that Save has no sidecar to file
/// one, the one gate the resolver answers (#1392). Its cause is
/// off this surface, so the reason draws INLINE, outside the
/// dim (#815).
struct DesktopsGroup: View {
    @ObservedObject var model: SettingsModel
    @State private var expanded = true

    private var gates: ProfilesGates {
        ProfilesGates(
            editingStoredProfile: model.editingStoredProfile,
            connectedScreens: model.displays.count,
            guiManaged: model.guiManaged,
            sidecarExists: model.sidecarExists
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
                rows.modifier(GreyOut(active: reason != nil))
                if let reason {
                    Text(ProfilesGateHelp.sentence(for: reason))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(
                            horizontal: false,
                            vertical: true
                        )
                }
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

    @ViewBuilder private var rows: some View {
        if desktopRows.isEmpty {
            emptyHint
        } else {
            ForEach(desktopRows, id: \.key) { row in
                spaceRow(row)
            }
        }
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

    func profileMenu(_ key: DesktopKey) -> some View {
        Picker("", selection: binding(key)) {
            Text(L("desktops.none", "None"))
                .tag(String?.none)
            ForEach(options(key), id: \.self) { name in
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
            binding(key).wrappedValue
                ?? L("desktops.none", "None")
        )
    }

    /// Rows from the one derivation the census shares
    /// (`ProfilesFamilyRows.desktops`), which gives a dormant
    /// record a row of its OWN even where a live Desktop holds
    /// the number it was last seen at.
    private var desktopRows: [DesktopRow] {
        ProfilesFamilyRows.desktops(
            onMain: model.mainDesktops,
            keys: model.desktopKeys,
            present: model.presentDesktopKeys,
            screens: model.desktopScreens,
            bindings: model.config.profileBindings
        )
    }

    /// The bound profile's screen count where Core's gate
    /// refuses it on the count — the binding stands aside then
    /// (#1394). Narrated, never re-decided: the verdict is
    /// `DesktopBindingRefusal.of`'s.
    func otherScreenCount(_ key: DesktopKey) -> Int? {
        guard let name = binding(key).wrappedValue,
            let count = model.profileSummaries.first(where: {
                $0.name == name
            })?.count,
            case .screenCount = DesktopBindingRefusal.of(
                profileCount: count,
                connected: model.displays.count
            )
        else { return nil }
        return count
    }

    /// Available profiles for the dropdown, always including the
    /// current binding even if its file has since been deleted.
    private func options(_ key: DesktopKey) -> [String] {
        var names = model.profiles
        if let bound = model.config.profileBindings[key]?.profile,
            !names.contains(bound)
        {
            names.append(bound)
        }
        return names
    }

    /// A live Desktop's record may still sit under the number it
    /// was filed at before Core re-keyed it, so a row looks under
    /// both of its keys — otherwise the picker reads empty for a
    /// binding the user can see on the row above.
    private func twin(_ key: DesktopKey) -> DesktopKey? {
        guard case .identity = key,
            let number = desktopRows.first(where: { $0.key == key })?
                .number
        else { return nil }
        return .number(number)
    }

    private func binding(_ key: DesktopKey) -> Binding<String?> {
        Binding(
            get: {
                model.config.profileBindings[key]?.profile
                    ?? twin(key).flatMap {
                        model.config.profileBindings[$0]?.profile
                    }
            },
            set: { profile in
                // The row BEFORE the twin drop below: a Desktop
                // bound only under its twin leaves the rows the
                // moment that record goes, and its projections
                // would fall to their nil arms.
                let row = desktopRows.first { $0.key == key }
                // Writing settles the ambiguity rather than
                // leaving two records for one Desktop, which
                // Core's drop rule would later resolve by
                // deleting the edit.
                if let twin = twin(key) {
                    model.config.profileBindings[twin] = nil
                }
                guard let profile else {
                    model.config.profileBindings[key] = nil
                    return
                }
                // The projections are refreshed from the reading
                // this row was built from, never invented.
                let number =
                    row?.number
                    ?? model.config.profileBindings[key]?.desktop
                    ?? key.number ?? 0
                model.config.profileBindings[key] = DesktopBinding(
                    profile: profile,
                    desktop: number,
                    screen: row?.screen
                        ?? model.config.profileBindings[key]?.screen
                )
            }
        )
    }
}
