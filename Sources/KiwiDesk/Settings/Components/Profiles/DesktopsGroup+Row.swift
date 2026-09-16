import KiwiDeskCore
import SwiftUI

/// One row of the Desktops card: the Desktop's number, the
/// screen it lives on (#1438), its badges and its picker for one
/// binding slot (#1436).
extension DesktopsGroup {
    func spaceRow(_ row: DesktopRow, slot: BindingSlot) -> some View {
        let number = row.number
        return HStack {
            Image(systemName: DesktopGlyph.symbol)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(
                    L(
                        "desktops.desktop",
                        "Desktop %1$d",
                        number
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
            // By the DESKTOP, never its number: a dormant record
            // and a live Desktop can share one, and both rows
            // then claim to be current (owner device QA).
            if row.key == model.currentDesktopKey {
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
            if row.isDormant {
                BadgeChip(
                    label: L(
                        "desktops.absent",
                        "not present"
                    )
                )
                // The badge alone can read as "your binding is
                // lost", which is the one thing this must not
                // mean — the sibling pin badge pairs a help for
                // the same reason.
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
            } else if !model.mainDesktops.contains(number) {
                BadgeChip(
                    label: L(
                        "desktops.not_on_main",
                        "not on main screen"
                    )
                )
            }
            Spacer()
            profileMenu(row.key, slot: slot)
        }
    }

    private func profileMenu(
        _ key: DesktopKey,
        slot: BindingSlot
    ) -> some View {
        Picker("", selection: binding(key, slot: slot)) {
            Text(L("desktops.none", "None"))
                .tag(String?.none)
            ForEach(options(key, slot: slot), id: \.self) { name in
                Text(name).tag(String?.some(name))
            }
        }
        .labelsHidden()
        .controlSize(.large)
        .frame(width: 180)
        // An empty title names nothing, so the picker is named
        // here — a count group's by its count, since one Desktop
        // draws a picker per group — and named, it owes its
        // selection back as the value (#812).
        .accessibilityLabel(pickerLabel(slot))
        .accessibilityValue(
            binding(key, slot: slot).wrappedValue
                ?? L("desktops.none", "None")
        )
    }

    private func pickerLabel(_ slot: BindingSlot) -> String {
        switch slot {
        case .count(let count):
            return L(
                "desktops.profile_ax.count",
                "Profile for this Desktop on %1$@",
                screensPhrase(count)
            )
        case .orphan:
            return L(
                "desktops.profile_ax",
                "Profile for this Desktop"
            )
        }
    }

    /// A count group offers the profiles saved for that count —
    /// the bind-fit question, asked of Core's one judgement
    /// (#1394) — and an orphan row only the name it clears.
    private func options(
        _ key: DesktopKey,
        slot: BindingSlot
    ) -> [String] {
        switch slot {
        case .count(let count):
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

    /// The slot's bound name: for a count, the record's entry
    /// saved for it; for an orphan, the name itself while bound.
    private func bound(_ key: DesktopKey, slot: BindingSlot) -> String? {
        guard let record = record(for: key) else { return nil }
        switch slot {
        case .count(let count):
            return record.profiles.first { profileCounts[$0] == count }
        case .orphan(let name):
            return record.profiles.contains(name) ? name : nil
        }
    }

    private func binding(
        _ key: DesktopKey,
        slot: BindingSlot
    ) -> Binding<String?> {
        Binding(
            get: { bound(key, slot: slot) },
            set: { write($0, key: key, slot: slot) }
        )
    }

    /// One slot's pick, filed on the Desktop's record: the slot's
    /// previous entry goes whatever comes in, the other slots'
    /// entries stay, and a record left empty is removed (#1436,
    /// `DesktopBindingGroupTests`).
    func write(_ profile: String?, key: DesktopKey, slot: BindingSlot) {
        // The row BEFORE the twin drop below: a Desktop bound
        // only under its twin leaves the rows the moment that
        // record goes, and its projections would fall to their
        // nil arms.
        let row = desktopRows.first { $0.key == key }
        var record =
            record(for: key)
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
        if let previous = bound(key, slot: slot) {
            record.unbind(previous)
        }
        if let profile {
            record.profiles.append(profile)
        }
        guard !record.profiles.isEmpty else {
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
