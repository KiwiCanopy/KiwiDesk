import KiwiDeskCore
import SwiftUI

/// A Desktop's screen-setup rows on the Desktops card (#1609):
/// each setup a binding is scoped to, the add menu, and the line
/// naming a holder an all-setups binding loads over.
extension DesktopsGroup {
    /// How far a Desktop's own rows sit in from its label.
    static let nestIndent: CGFloat = 26
    /// The × column's width, reserved on the fallback row too so
    /// a Desktop's pickers keep one trailing edge.
    static let removeColumn: CGFloat = 18

    /// One screen setup's row: its name as the Saved profiles
    /// chips name it, static, its picker, and the × that removes
    /// it (owner, 2026-09-23).
    func setupRow(_ row: DesktopRow, slot: BindingSlot) -> some View {
        let setup: [String]
        if case .count(_, let scoped?) = slot {
            setup = scoped
        } else {
            setup = []
        }
        let label = model.setupLabels([setup])[0]
        return HStack {
            HStack(spacing: 4) {
                Image(systemName: "display")
                Text(label)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                L("profiles.sets.chip.ax", "Screen setup: %1$@", label)
            )
            if model.isConnectedSetup(setup) {
                BadgeChip(
                    label: L("profiles.sets.connected", "connected")
                )
            }
            Spacer()
            profileMenu(
                row,
                slot: slot,
                name: L(
                    "desktops.profile_ax.setup",
                    "Profile for this Desktop on %1$@",
                    label
                )
            )
            Button {
                clear(row, slot: slot)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .frame(width: Self.removeColumn)
            .iconButtonAffordance(
                L(
                    "desktops.scope.remove",
                    "Remove the profile for %1$@",
                    label
                )
            )
        }
        .padding(.leading, Self.nestIndent)
    }

    /// Whether a Desktop draws the add menu: its count offers two
    /// setups or more — with one, there is nothing to add — or the
    /// record already scopes one of that count (#1609).
    func offersSetups(count: Int, row: DesktopRow) -> Bool {
        let counts = profileCounts
        return (model.bindableSetups[count]?.count ?? 0) >= 2
            || row.binding?.entries.contains {
                $0.setup != nil && counts[$0.profile] == count
            } == true
    }

    /// The setups of `count` this Desktop has no row for yet, in
    /// Core's order — the connected one first.
    private func unscopedSetups(
        _ row: DesktopRow,
        count: Int
    ) -> [ClaimableMonitorSet] {
        let scoped = Set(
            row.binding?.entries.compactMap(\.setup) ?? []
        )
        return (model.bindableSetups[count] ?? []).filter {
            !scoped.contains($0.monitors)
        }
    }

    /// "Add a screen setup": a menu of the setups without a row
    /// here. A pick adds the row with the setup's HOLDER — the
    /// profile that loads there when nothing is bound, so adding
    /// it is also the fix for the conflict line below — and moves
    /// focus to its picker.
    func addSetupMenu(_ row: DesktopRow, count: Int) -> some View {
        let choices = unscopedSetups(row, count: count)
        let labels = model.setupLabels(choices.map(\.monitors))
        return Menu {
            Section(
                L(
                    "desktops.scope.add.header",
                    "Screen setups without a profile on this Desktop"
                )
            ) {
                if choices.isEmpty {
                    Text(
                        L(
                            "desktops.scope.add.none",
                            "Every screen setup already has a profile "
                                + "here"
                        )
                    )
                }
                ForEach(choices.indices, id: \.self) { index in
                    Button {
                        addSetup(choices[index], count: count, row: row)
                    } label: {
                        Text(labels[index])
                        let detail = setupDetail(choices[index])
                        if !detail.isEmpty { Text(detail) }
                    }
                }
            }
        } label: {
            // Neutral on the LABEL: on the Menu, its tint would also
            // fill the bordered bezel near-black (#1393).
            Label(addTitle, systemImage: "plus")
                .neutralMenuLabel()
        }
        // A pull-down, bordered like the window's text actions, its
        // chevron saying a list opens (#1393).
        .menuStyle(.button)
        .buttonStyle(.bordered)
        .menuIndicator(.visible)
        .fixedSize()
        .help(addTitle)
        .accessibilityLabel(
            L(
                "desktops.scope.add.ax",
                "Add a screen setup to Desktop %1$d",
                row.number
            )
        )
        // Named, so it owes a value (#812): how many setups it
        // offers, the number last.
        .accessibilityValue(
            L(
                "profiles.sets.add.ax_value",
                "Screen setups to choose from: %1$d",
                choices.count
            )
        )
    }

    private var addTitle: String {
        L("desktops.scope.add", "Add a screen setup")
    }

    private func addSetup(
        _ choice: ClaimableMonitorSet,
        count: Int,
        row: DesktopRow
    ) {
        guard let profile = choice.owner ?? fallbackProfile(count)
        else { return }
        let slot = BindingSlot.count(count, setup: choice.monitors)
        write(profile, key: row.key, slot: slot)
        focusedSlot = BindingFocus(key: row.key, slot: slot)
    }

    /// For a setup nobody holds: the count's default, else its
    /// first profile.
    private func fallbackProfile(_ count: Int) -> String? {
        let peers = model.profileSummaries.filter { $0.count == count }
        return (peers.first { $0.isUsableDefault } ?? peers.first)?.name
    }

    private func setupDetail(_ choice: ClaimableMonitorSet) -> String {
        switch (choice.isConnected, choice.owner) {
        case (true, let owner?):
            return L(
                "profiles.sets.add.connected_held_by",
                "Connected · currently in “%1$@”",
                owner
            )
        case (true, nil):
            return L("profiles.sets.add.connected", "Connected now")
        case (false, let owner?):
            return L(
                "profiles.sets.add.held_by",
                "Currently in “%1$@”",
                owner
            )
        case (false, nil):
            return ""
        }
    }

    /// Where a Desktop's all-setups binding loads over the profile
    /// holding the connected setup, one caption says so — Core's
    /// reading, never a re-derived ladder (#1609). Only a live
    /// Desktop on the main screen can fire, so only it says so.
    @ViewBuilder func conflictLine(_ row: DesktopRow) -> some View {
        if !row.isDormant, model.mainDesktops.contains(row.number),
            let reading = row.binding.flatMap({ model.bindingReadings[$0] }),
            let holder = reading.over
        {
            Text(
                L(
                    "desktops.conflict",
                    "Loads %1$@ over %2$@, which holds these screens.",
                    reading.name,
                    holder
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.leading, Self.nestIndent)
        }
    }
}
