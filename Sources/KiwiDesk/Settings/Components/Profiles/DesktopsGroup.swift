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
    /// The picker a screen-setup row's add or removal hands
    /// focus to (#1609).
    @FocusState var focusedSlot: BindingFocus?

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
                + "others. For each screen count, a Desktop can "
                + "load a profile on each screen setup you add, and "
                + "one on all other screen setups. A screen setup "
                + "you added comes first; otherwise the profile for "
                + "all other screen setups loads, even over the "
                + "profile that holds those screens."
        )
    }

    private var intro: String {
        L(
            "desktops.intro",
            "These are your Mac's own Desktops, from Mission "
                + "Control — not KiwiDesk's Spaces; under each "
                + "is the screen it is on, or was last seen on "
                + "while it isn't present. Pick a profile to "
                + "load automatically when a Desktop activates "
                + "on your main screen (the one with the menu "
                + "bar)."
        )
    }

    /// The count groups, then the orphans (#1436). A group
    /// whose count has no saved profile is not drawn — a
    /// None-only picker is a dead control — so a connected count
    /// with none takes the caption in its place; with no display
    /// reading at all there is no connected count to speak of.
    @ViewBuilder private var rows: some View {
        if desktopRows.isEmpty {
            emptyHint
        } else {
            if counts.leading == nil, !counts.displaysUnknown {
                caption(noProfileForCount)
            }
            ForEach(groups, id: \.self) { group in
                groupView(group)
            }
        }
    }

    @ViewBuilder private func groupView(
        _ group: BindingGroup
    ) -> some View {
        switch group {
        case .count(let count, let leads, let rows):
            if drawsHeaders { header(forCount: count, leads: leads) }
            ForEach(rows, id: \.key) { row in
                desktopBlock(row, count: count, leads: leads)
            }
        case .orphans(let orphans):
            SettingsGroupHeader(
                L("profiles.broken.title", "Couldn't load")
            )
            ForEach(orphans, id: \.self) { orphan in
                orphanRow(orphan.row, profile: orphan.profile)
            }
        }
    }

    /// Headers only where there is more than one group to tell
    /// apart, or where the one drawn is not the leading one — a
    /// single-count user sees the card unchanged.
    private var drawsHeaders: Bool {
        guard groups.count == 1, case .count(_, let leads, _) = groups[0]
        else { return true }
        return !leads
    }

    private func header(forCount count: Int, leads: Bool) -> some View {
        let title: String
        if leads {
            title =
                count == 1
                ? L("presets.for_your.one", "For your 1 screen")
                : L(
                    "presets.for_your.many",
                    "For your %1$d screens",
                    count
                )
        } else {
            title =
                count == 1
                ? L("desktops.for_count.one", "For 1 screen")
                : L("desktops.for_count.many", "For %1$d screens", count)
        }
        return SettingsGroupHeader(title).padding(.top, 4)
    }

    private var emptyHint: some View {
        caption(
            L(
                "desktops.empty",
                "No native macOS Desktops detected. Add "
                    + "Desktops in Mission Control to bind "
                    + "profiles."
            )
        )
    }

    private var noProfileForCount: String {
        let connected = model.displays.count
        return connected == 1
            ? L(
                "desktops.no_profile_for_count.one",
                "No profile is saved for 1 screen yet, so no "
                    + "Desktop binding applies right now."
            )
            : L(
                "desktops.no_profile_for_count.many",
                "No profile is saved for %1$d screens yet, so no "
                    + "Desktop binding applies right now.",
                connected
            )
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Rows from the one derivation the census shares
    /// (`ProfilesFamilyRows.desktops`), which gives a dormant
    /// record a row of its OWN even where a live Desktop holds
    /// the number it was last seen at.
    var desktopRows: [DesktopRow] {
        ProfilesFamilyRows.desktops(
            onMain: model.mainDesktops,
            keys: model.desktopKeys,
            present: model.presentDesktopKeys,
            screens: model.desktopScreens,
            bindings: model.config.profileBindings
        )
    }

    /// The groups from the same derivation the census expands
    /// (`ProfilesFamilyRows.bindingGroups`).
    private var groups: [BindingGroup] {
        ProfilesFamilyRows.bindingGroups(
            rows: desktopRows,
            counts: counts,
            profileCounts: profileCounts
        )
    }

    private var counts: BindingCounts {
        ProfilesFamilyRows.bindingCounts(
            profiles: model.profileSummaries,
            connected: model.displays.count
        )
    }

    var profileCounts: [String: Int] {
        ProfilesFamilyRows.profileCounts(model.profileSummaries)
    }

    /// A live Desktop's record may still sit under the number it
    /// was filed at before Core re-keyed it, so a row looks under
    /// both of its keys — otherwise the picker reads empty for a
    /// binding the user can see on the row above.
    ///
    /// A DORMANT identity row has no twin: its number is where
    /// it was last seen, which a live Desktop may hold now, and
    /// that Desktop's own record is not this row's to drop.
    func twin(_ key: DesktopKey) -> DesktopKey? {
        guard case .identity = key,
            let row = desktopRows.first(where: { $0.key == key }),
            !row.isDormant
        else { return nil }
        return .number(row.number)
    }
}
