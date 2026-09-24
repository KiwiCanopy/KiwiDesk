import KiwiDeskCore
import SwiftUI

/// The profile whose full screen-setup list is open (#843).
struct ScreenSetupListRequest: Identifiable {
    let id: String
}

/// A profile row's screen setups (#1530): one passive chip per
/// setup naming its screens, one counted chip past `inlineLimit`,
/// and a trailing `+` that moves another setup here. No ×: a
/// setup leaves a profile only by another taking it (ruled).
extension ProfilesSection {
    /// Past this many setups the row collapses to one counted chip.
    static let inlineLimit = 2

    func screenSetupsLine(_ summary: ProfileSummary) -> some View {
        HStack(spacing: 4) {
            if summary.isDormant {
                Text(dormantCaption(summary))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else if summary.sets.count > Self.inlineLimit {
                collapsedSetups(summary)
            } else {
                let labels = model.setupLabels(summary.sets)
                ForEach(summary.sets.indices, id: \.self) { index in
                    setupChip(
                        summary.sets[index],
                        label: labels[index]
                    )
                }
            }
            addSetupMenu(summary)
        }
    }

    private func dormantCaption(_ summary: ProfileSummary) -> String {
        summary.isDefault
            ? L(
                "profiles.sets.dormant_default",
                "No screen setup yet, so it isn't loaded as the "
                    + "default — it takes one when you load it."
            )
            : L(
                "profiles.sets.dormant",
                "No screen setup yet — takes one when you load it."
            )
    }

    /// One setup: a passive capsule naming its screens.
    private func setupChip(
        _ monitors: [String],
        label: String
    ) -> some View {
        HStack(spacing: 3) {
            Image(systemName: "display")
            Text(label)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .font(.caption2)
        .frame(maxWidth: 180, alignment: .leading)
        .fixedSize(horizontal: true, vertical: false)
        .chipSurface()
        .help(label)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(setupSpoken(label))
        .accessibilityValue(connectedValue(monitors))
    }

    private func setupSpoken(_ label: String) -> String {
        L("profiles.sets.chip.ax", "Screen setup: %1$@", label)
    }

    private func connectedValue(_ monitors: [String]) -> String {
        model.isConnectedSetup(monitors)
            ? L("profiles.sets.connected", "connected")
            : ""
    }

    /// The counted chip standing in for three or more setups.
    private func collapsedSetups(
        _ summary: ProfileSummary
    ) -> some View {
        Button {
            setupListRequest = ScreenSetupListRequest(id: summary.name)
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "display")
                Text("\(summary.sets.count)")
                Image(systemName: "chevron.down")
                    .imageScale(.small)
            }
            .font(.caption2)
        }
        .buttonStyle(.borderless)
        .hoverHighlight(cornerRadius: 5, padding: 3)
        .accessibilityLabel(
            L(
                "profiles.sets.collapsed.ax",
                "Screen setups: %1$d",
                summary.sets.count
            )
        )
        .accessibilityHint(
            L(
                "profiles.sets.collapsed.hint",
                "Shows every screen setup this profile holds"
            )
        )
        .popover(item: setupListBinding(summary.name)) { _ in
            setupList(summary)
        }
    }

    private func setupListBinding(
        _ name: String
    ) -> Binding<ScreenSetupListRequest?> {
        Binding(
            get: {
                setupListRequest?.id == name ? setupListRequest : nil
            },
            set: { setupListRequest = $0 }
        )
    }

    private func setupList(_ summary: ProfileSummary) -> some View {
        let labels = model.setupLabels(summary.sets)
        return VStack(alignment: .leading, spacing: 6) {
            ForEach(summary.sets.indices, id: \.self) { index in
                HStack(spacing: 6) {
                    Image(systemName: "display")
                    Text(labels[index])
                    if model.isConnectedSetup(summary.sets[index]) {
                        BadgeChip(
                            label: L("profiles.sets.connected", "connected")
                        )
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(setupSpoken(labels[index]))
                .accessibilityValue(connectedValue(summary.sets[index]))
            }
        }
        .font(.callout)
        .padding(12)
    }

    /// The `+`: a menu of the setups this profile could take.
    private func addSetupMenu(_ summary: ProfileSummary) -> some View {
        let choices = model.claimableSetups(for: summary.name)
        let labels = model.setupLabels(choices.map(\.monitors))
        return Menu {
            Section(
                L(
                    "profiles.sets.add.header",
                    "Move a screen setup to “%1$@”",
                    summary.name
                )
            ) {
                if choices.isEmpty {
                    Text(
                        L(
                            "profiles.sets.add.none",
                            "No other screen setup fits this profile"
                        )
                    )
                }
                ForEach(choices.indices, id: \.self) { index in
                    Button {
                        model.claimScreenSetup(
                            choices[index].monitors,
                            for: summary.name
                        )
                    } label: {
                        Text(labels[index])
                        Text(choiceDetail(choices[index]))
                    }
                }
            }
        } label: {
            // The icon ink, which the neutral menu label's own ink
            // would otherwise outrank (#1393).
            Image(systemName: "plus")
                .foregroundStyle(SettingsTheme.ink2)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .neutralMenuLabel()
        .iconButtonAffordance(
            L("profiles.sets.move.help", "Move a screen setup here"),
            resting: true
        )
        .accessibilityValue(
            L(
                "profiles.sets.add.ax_value",
                "Screen setups to choose from: %1$d",
                choices.count
            )
        )
    }

    private func choiceDetail(_ choice: ClaimableMonitorSet) -> String {
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
}
