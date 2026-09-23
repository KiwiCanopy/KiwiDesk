import KiwiDeskCore
import SwiftUI

/// The Desktops card's writes (#1436, #1609): what each picker
/// offers and reads, and the one write every pick and removal
/// files through.
extension DesktopsGroup {
    /// A count slot offers the profiles saved for that count —
    /// the bind-fit question, asked of Core's one judgement
    /// (#1394) — and an orphan row only the name it clears.
    func options(_ slot: BindingSlot) -> [String] {
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
    func bound(_ row: DesktopRow, slot: BindingSlot) -> String? {
        guard let record = row.binding else { return nil }
        switch slot {
        case .count(let count, let setup):
            return record.ranked(
                scope: setup,
                preferring: model.activeProfile
            )
            .first { profileCounts[$0.profile] == count }?.profile
        case .orphan(let name):
            return record.profiles.contains(name) ? name : nil
        }
    }

    /// `bound` by key, for a test that holds no row.
    func boundName(key: DesktopKey, slot: BindingSlot) -> String? {
        desktopRows.first { $0.key == key }.flatMap { bound($0, slot: slot) }
    }

    func binding(
        _ row: DesktopRow,
        slot: BindingSlot
    ) -> Binding<String?> {
        Binding(
            get: { bound(row, slot: slot) },
            set: { name in
                guard name == nil else {
                    write(name, key: row.key, slot: slot)
                    return
                }
                clear(row, slot: slot)
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

    /// A removal — None, or a setup row's × — with the focus it
    /// owes (#1609): a removed
    /// screen-setup row hands focus to its Desktop's always-drawn
    /// fallback picker, and a record the removal empties — a
    /// dormant row then leaves the card — to the neighbouring
    /// Desktop's, read BEFORE the write (`DeletionFocus`, #816).
    func clear(_ row: DesktopRow, slot: BindingSlot) {
        let keys = desktopRows.map(\.key)
        let neighbour = DeletionFocus.neighbour(after: row.key, in: keys)
        write(nil, key: row.key, slot: slot)
        guard case .count(let count, let setup) = slot else { return }
        let others = BindingSlot.count(count, setup: nil)
        if desktopRows.contains(where: { $0.key == row.key }) {
            if setup != nil {
                focusedSlot = BindingFocus(key: row.key, slot: others)
            }
        } else if let neighbour {
            focusedSlot = BindingFocus(key: neighbour, slot: others)
        }
    }
}
