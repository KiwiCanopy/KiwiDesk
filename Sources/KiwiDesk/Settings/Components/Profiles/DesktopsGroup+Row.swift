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
        let fallback = fallbackLabel(count: count, scoped: slots.count > 1)
        VStack(alignment: .leading, spacing: 4) {
            desktopLabel(row)
            ForEach(slots.dropLast(), id: \.self) { slot in
                setupRow(row, slot: slot)
            }
            // Only where a second setup is known is there one to
            // add (owner, 2026-09-23).
            if offersSetups(count: count, row: row) {
                addSetupMenu(row, count: count)
                    .padding(.leading, Self.nestIndent)
            }
            // The scope is always WRITTEN, one setup known or many:
            // a bare picker binds every setup of the count without
            // saying so (owner, 2026-09-23).
            HStack {
                Text(fallback).accessibilityHidden(true)
                Spacer()
                profileMenu(row, slot: others, name: fallback)
                Color.clear.frame(width: Self.removeColumn, height: 1)
                    .accessibilityHidden(true)
            }
            .padding(.leading, Self.nestIndent)
            if leads { conflictLine(row) }
        }
    }

    /// The fallback row's label, naming the screen count its
    /// binding stops at: all screen setups of that count, or all
    /// OTHER ones once a setup has a row of its own. The count is
    /// last, so no locale has to agree with it.
    func fallbackLabel(count: Int, scoped: Bool) -> String {
        switch (scoped, count == 1) {
        case (false, true):
            return L(
                "desktops.scope.all.one",
                "All screen setups with 1 screen"
            )
        case (false, false):
            return L(
                "desktops.scope.all.many",
                "All screen setups with %1$d screens",
                count
            )
        case (true, true):
            return L(
                "desktops.scope.others.one",
                "All other screen setups with 1 screen"
            )
        case (true, false):
            return L(
                "desktops.scope.others.many",
                "All other screen setups with %1$d screens",
                count
            )
        }
    }

    /// An orphan's row: a bound name no saved profile counts.
    func orphanRow(_ row: DesktopRow, profile: String) -> some View {
        HStack {
            desktopLabel(row)
            Spacer()
            profileMenu(
                row,
                slot: .orphan(profile),
                name: L("desktops.profile_ax", "Profile for this Desktop")
            )
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

    /// A slot's picker, named for VoiceOver by `name` — the
    /// fallback row's own label, a setup's, or an orphan's.
    func profileMenu(
        _ row: DesktopRow,
        slot: BindingSlot,
        name: String
    ) -> some View {
        Picker("", selection: binding(row, slot: slot)) {
            // A screen-setup row has no empty choice — its × removes
            // it — and the fallback's says what it means: no
            // binding, so the rungs below it answer (#1609).
            if let none = noneLabel(slot) {
                Text(none).tag(String?.none)
            }
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
        .accessibilityLabel(name)
        .accessibilityValue(
            binding(row, slot: slot).wrappedValue
                ?? noneLabel(slot)
                ?? L("desktops.none", "None")
        )
    }

    /// The picker's empty choice: "No binding" on the fallback —
    /// the rungs below it answer — None on an orphan, and none on
    /// a setup row, whose × removes it.
    private func noneLabel(_ slot: BindingSlot) -> String? {
        switch slot {
        case .count(_, _?): return nil
        case .count: return L("desktops.no_binding", "No binding")
        case .orphan: return L("desktops.none", "None")
        }
    }
}
