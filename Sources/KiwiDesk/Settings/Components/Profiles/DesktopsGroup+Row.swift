import KiwiDeskCore
import SwiftUI

/// Which picker holds keyboard focus on the Desktops card — a
/// row's slot, stated when a screen-setup row is added or removed
/// (#1609).
struct BindingFocus: Hashable {
    let key: DesktopKey
    let slot: BindingSlot
}

/// One Desktop on the Desktops card (#1436, #1609): its number,
/// the screen it lives on (#1438), its badges, and a picker per
/// binding slot — one line while it holds no screen-setup row,
/// else the ladder's own order: each setup's row, the add row,
/// then all other screen setups.
extension DesktopsGroup {
    @ViewBuilder func desktopBlock(
        _ row: DesktopRow,
        count: Int,
        leads: Bool
    ) -> some View {
        let slots = ProfilesFamilyRows.slots(
            of: row,
            count: count,
            profileCounts: profileCounts
        )
        let others = BindingSlot.count(count, setup: nil)
        VStack(alignment: .leading, spacing: 4) {
            if slots.count == 1 {
                HStack {
                    desktopLabel(row)
                    Spacer()
                    profileMenu(row, slot: others, nested: false)
                    if offersSetups(count: count, row: row) {
                        addSetupMenu(row, count: count, iconOnly: true)
                    }
                }
            } else {
                desktopLabel(row)
                ForEach(slots.dropLast(), id: \.self) { slot in
                    setupRow(row, slot: slot)
                }
                addSetupMenu(row, count: count, iconOnly: false)
                    .padding(.leading, Self.nestIndent)
                HStack {
                    Text(
                        L(
                            "desktops.scope.others",
                            "All other screen setups"
                        )
                    )
                    .accessibilityHidden(true)
                    Spacer()
                    profileMenu(row, slot: others, nested: true)
                }
                .padding(.leading, Self.nestIndent)
            }
            if leads { conflictLine(row) }
        }
    }

    /// An orphan's row: a bound name no saved profile counts.
    func orphanRow(_ row: DesktopRow, profile: String) -> some View {
        HStack {
            desktopLabel(row)
            Spacer()
            profileMenu(row, slot: .orphan(profile), nested: false)
        }
    }

    /// The Desktop's glyph, number, screen line and badges.
    func desktopLabel(_ row: DesktopRow) -> some View {
        HStack {
            Image(systemName: DesktopGlyph.symbol)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(
                    L(
                        "desktops.desktop",
                        "Desktop %1$d",
                        row.number
                    )
                )
                .fontWeight(.medium)
                // Which screen the Desktop lives on (#1438) —
                // for a dormant row, the one it was last seen
                // on, since the number alone cannot say.
                if let screen = row.screen {
                    Text(screen)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            badges(row)
        }
    }

    /// By the DESKTOP, never its number: a dormant record and a
    /// live Desktop can share one, and both rows then claim to be
    /// current (owner device QA). A bound Desktop that cannot
    /// fire here is BADGED, never greyed — its picker is the only
    /// way to change or clear it (ui-designer, 2026-08-18) — and
    /// an absent one keeps its record, absence never being proof
    /// it is gone (#1147).
    @ViewBuilder private func badges(_ row: DesktopRow) -> some View {
        if row.key == model.currentDesktopKey {
            BadgeChip(label: L("desktops.current", "current"))
        }
        if row.isDormant {
            BadgeChip(label: L("desktops.absent", "not present"))
                // The badge alone can read as "your binding is
                // lost", which is the one thing it must not mean.
                .help(
                    L(
                        "desktops.absent.help",
                        "This Desktop isn't in Mission Control "
                            + "right now — its screen is "
                            + "unplugged, or it was removed. The "
                            + "profile stays here and loads "
                            + "again if that Desktop comes back."
                    )
                )
        } else if !model.mainDesktops.contains(row.number) {
            BadgeChip(
                label: L(
                    "desktops.not_on_main",
                    "not on main screen"
                )
            )
        }
    }

    func profileMenu(
        _ row: DesktopRow,
        slot: BindingSlot,
        nested: Bool
    ) -> some View {
        Picker("", selection: binding(row, slot: slot)) {
            Text(L("desktops.none", "None"))
                .tag(String?.none)
            ForEach(options(slot), id: \.self) { name in
                Text(name).tag(String?.some(name))
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .neutralMenuLabel()
        .controlSize(.large)
        // A pop-up draws at the width of its widest option
        // whatever frame it is given — asked to fill, it still
        // does not (measured 2026-09-16) — so two groups offering
        // different profiles draw two widths. Trailing-aligned,
        // the column keeps one edge, as System Settings' does.
        .frame(width: 180, alignment: .trailing)
        .focused(
            $focusedSlot,
            equals: BindingFocus(key: row.key, slot: slot)
        )
        // An empty title names nothing, so the picker is named
        // here, and named, it owes its selection back as the
        // value (#812).
        .accessibilityLabel(pickerLabel(slot, nested: nested))
        .accessibilityValue(
            binding(row, slot: slot).wrappedValue
                ?? L("desktops.none", "None")
        )
    }

    private func pickerLabel(_ slot: BindingSlot, nested: Bool) -> String {
        switch slot {
        case .count(_, let setup?):
            return L(
                "desktops.profile_ax.setup",
                "Profile for this Desktop on %1$@",
                model.setupLabels([setup])[0]
            )
        case .count:
            guard !nested else {
                return L(
                    "desktops.profile_ax.others",
                    "Profile for this Desktop on all other screen "
                        + "setups"
                )
            }
            return countLabel(slot)
        case .orphan:
            return L(
                "desktops.profile_ax",
                "Profile for this Desktop"
            )
        }
    }

    /// A one-line Desktop's picker, named by its count group,
    /// since one Desktop draws a picker per group.
    private func countLabel(_ slot: BindingSlot) -> String {
        guard case .count(let count, _) = slot else { return "" }
        return count == 1
            ? L(
                "desktops.profile_ax.count.one",
                "Profile for this Desktop on 1 screen"
            )
            : L(
                "desktops.profile_ax.count.many",
                "Profile for this Desktop on %1$d screens",
                count
            )
    }

    /// A count slot offers the profiles saved for that count —
    /// the bind-fit question, asked of Core's one judgement
    /// (#1394) — and an orphan row only the name it clears.
    private func options(_ slot: BindingSlot) -> [String] {
        switch slot {
        case .count(let count, _):
            return model.profileSummaries.filter {
                DesktopBindingRefusal.of(
                    profileCount: $0.count,
                    connected: count
                ) == nil
            }
            .map(\.name)
        case .orphan(let name):
            return [name]
        }
    }

    /// The slot's bound name off the row's own record: for a
    /// count, the entry of that count and scope, the live profile
    /// first — the gate's own preference, so the picker names
    /// what fires; for an orphan, the name itself while bound.
    private func bound(_ row: DesktopRow, slot: BindingSlot) -> String? {
        guard let record = row.binding else { return nil }
        switch slot {
        case .count(let count, let setup):
            let names = record.entries.filter {
                $0.setup == setup && profileCounts[$0.profile] == count
            }
            .map(\.profile)
            return names.first { $0 == model.activeProfile }
                ?? names.first
        case .orphan(let name):
            return record.profiles.contains(name) ? name : nil
        }
    }

    /// `bound` by key, for a test that holds no row.
    func boundName(key: DesktopKey, slot: BindingSlot) -> String? {
        desktopRows.first { $0.key == key }.flatMap { bound($0, slot: slot) }
    }

    private func binding(
        _ row: DesktopRow,
        slot: BindingSlot
    ) -> Binding<String?> {
        Binding(
            get: { bound(row, slot: slot) },
            set: { name in
                write(name, key: row.key, slot: slot)
                // None removes a screen-setup row, and focus
                // would fall to the top of the window with it:
                // it moves to the Desktop's always-drawn
                // fallback picker instead (#1609).
                if name == nil, case .count(let count, _?) = slot {
                    focusedSlot = BindingFocus(
                        key: row.key,
                        slot: .count(count, setup: nil)
                    )
                }
            }
        )
    }

    /// One slot's pick, filed on the Desktop's record through the
    /// record's own algebra: every entry of the slot's count AND
    /// scope goes whatever comes in, the other slots' entries
    /// stay, and a record left empty is removed (#1436, #1609,
    /// `DesktopBindingGroupTests`).
    func write(_ profile: String?, key: DesktopKey, slot: BindingSlot) {
        // The row BEFORE the twin drop below: a Desktop bound
        // only under its twin leaves the rows the moment that
        // record goes, and its projections would fall to their
        // nil arms.
        let row = desktopRows.first { $0.key == key }
        var record =
            row?.binding
            ?? model.config.profileBindings[key]
            ?? DesktopBinding(
                profiles: [],
                desktop: row?.number ?? key.number ?? 0
            )
        // Writing settles the ambiguity rather than leaving two
        // records for one Desktop, which Core's drop rule would
        // later resolve by deleting the edit.
        if let twin = twin(key) {
            model.config.profileBindings[twin] = nil
        }
        let counts = profileCounts
        switch (slot, profile) {
        case (.count(_, let setup), let profile?):
            record.bind(profile, setup: setup) { counts[$0] }
        case (.count(let count, let setup), nil):
            record.unbind(count: count, setup: setup) { counts[$0] }
        case (.orphan(let name), _):
            record.unbind(name)
        }
        defer { model.refreshBindingReadings() }
        guard !record.entries.isEmpty else {
            model.config.profileBindings[key] = nil
            return
        }
        // The projections are refreshed from the reading this
        // row was built from, never invented.
        if let row {
            record.desktop = row.number
            record.screen = row.screen ?? record.screen
        }
        model.config.profileBindings[key] = record
    }
}
