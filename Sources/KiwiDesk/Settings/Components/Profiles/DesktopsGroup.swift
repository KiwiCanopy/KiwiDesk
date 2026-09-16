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
                + "others. A Desktop can hold one profile per "
                + "screen count: the one saved for as many "
                + "screens as are connected loads, and the "
                + "others wait until that many are."
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

    /// The count groups, then the orphans (#1436). A group
    /// whose count has no saved profile is not drawn — a
    /// None-only picker is a dead control — so a connected count
    /// with none takes the caption in its place.
    @ViewBuilder private var rows: some View {
        if desktopRows.isEmpty {
            emptyHint
        } else {
            if !groups.contains(where: {
                if case .count(model.displays.count, _) = $0 {
                    return true
                }
                return false
            }) {
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
        case .count(let count, let rows):
            if drawsHeaders { header(forCount: count) }
            ForEach(rows, id: \.key) { row in
                spaceRow(row, slot: .count(count))
            }
        case .orphans(let orphans):
            SettingsGroupHeader(
                L("profiles.broken.title", "Couldn't load")
            )
            ForEach(orphans, id: \.self) { orphan in
                spaceRow(orphan.row, slot: .orphan(orphan.profile))
            }
        }
    }

    /// Headers only where there is more than one group to tell
    /// apart, or where the one drawn is not the connected
    /// count's — a single-count user sees the card unchanged.
    private var drawsHeaders: Bool {
        guard groups.count == 1, case .count(let count, _) = groups[0]
        else { return true }
        return count != model.displays.count
    }

    private func header(forCount count: Int) -> some View {
        let leads =
            DesktopBindingRefusal.of(
                profileCount: count,
                connected: model.displays.count
            ) == nil
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
        L(
            "desktops.no_profile_for_count",
            "No profile is saved for your %1$@ yet, so no "
                + "Desktop binding applies right now.",
            screensPhrase(model.displays.count)
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
            counts: ProfilesFamilyRows.bindingCounts(
                profiles: model.profileSummaries,
                connected: model.displays.count
            ),
            profileCounts: profileCounts,
            binding: { record(for: $0.key) }
        )
    }

    /// Each readable saved profile's screen count by name.
    var profileCounts: [String: Int] {
        Dictionary(
            model.profileSummaries.map { ($0.name, $0.count) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    /// A live Desktop's record may still sit under the number it
    /// was filed at before Core re-keyed it, so a row looks under
    /// both of its keys — otherwise the picker reads empty for a
    /// binding the user can see on the row above.
    func twin(_ key: DesktopKey) -> DesktopKey? {
        guard case .identity = key,
            let number = desktopRows.first(where: { $0.key == key })?
                .number
        else { return nil }
        return .number(number)
    }

    /// The record a row edits, under either of its keys.
    func record(for key: DesktopKey) -> DesktopBinding? {
        model.config.profileBindings[key]
            ?? twin(key).flatMap { model.config.profileBindings[$0] }
    }
}
