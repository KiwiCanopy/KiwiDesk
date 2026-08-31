import KiwiDeskCore
import SwiftUI

/// Drop target tray for Spaces assigned to dynamic main display
/// (`MonitorTray`, #36, #678).
struct FollowsMainTray: View {
    @ObservedObject var model: SettingsModel
    let rows: MonitorsFamilyRows
    let size: CGSize
    @State private var targeted = false
    @State private var showingOverflow = false

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: MonitorCardChips.stackSpacing
        ) {
            header
            chips
        }
        .padding(MonitorCardChips.cardPadding)
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .topLeading
        )
        // NO plate: the tray is a ROLE, not hardware — the card
        // fill/radius/stroke made it read as a fourth monitor
        // hovering above the desk. It carries a wash only while a
        // drop is over it, the cards' own targeting channel.
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.tint.opacity(targeted ? 0.2 : 0))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    .tint.opacity(targeted ? 1 : 0.55),
                    style: StrokeStyle(
                        lineWidth: targeted ? 2 : 1,
                        dash: [4]
                    )
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .dropDestination(for: DraggableSpace.self) { items, _ in
            assign(items)
        } isTargeted: { hovering in
            targeted = hovering
        }
    }

    private var header: some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.right")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
            Text(
                L(
                    "monitor_card.follows_main",
                    "Follows main display"
                )
            )
            .font(.caption2)
            .bold()
            .lineLimit(1)
            .truncationMode(.tail)
            Spacer(minLength: 0)
        }
        .frame(height: MonitorCardChips.trayHeaderHeight)
    }

    @ViewBuilder private var chips: some View {
        let spaces = rows.trayChips
        if spaces.isEmpty {
            Text(L("monitor_card.drop_here", "Drop a Space here"))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        } else {
            let split = MonitorCardChips.split(
                spaces,
                in: size,
                header: MonitorCardChips.trayHeaderHeight
            )
            HStack(
                alignment: .top,
                spacing: MonitorCardChips.spacing
            ) {
                WrapChips(split.shown) { space in
                    chip(space)
                }
                if split.overflow > 0 {
                    overflowChip(spaces, split.overflow)
                }
            }
        }
    }

    private func chip(_ space: SpaceID) -> some View {
        SpaceAssignmentChip(
            model: model,
            space: space,
            kind: .main,
            displays: rows.orderedDisplays
        )
    }

    /// Overflow chip showing popover with remaining spaces
    /// (`MonitorCardChips`).
    private func overflowChip(
        _ all: [SpaceID],
        _ count: Int
    ) -> some View {
        Button {
            showingOverflow = true
        } label: {
            Text(L("monitor_card.more_spaces", "+%1$d", count))
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
                .frame(width: MonitorCardChips.markerWidth)
                .padding(.vertical, 3)
                .background(Capsule().fill(.tint.opacity(0.15)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            L(
                "monitor_card.more_spaces.axlabel",
                "%1$d more Spaces on this display",
                count
            )
        )
        .popover(isPresented: $showingOverflow) {
            WrapChips(all) { space in
                chip(space)
            }
            .frame(width: 240)
            .padding(12)
        }
    }

    private func assign(_ items: [DraggableSpace]) -> Bool {
        var assigned = false
        for item in items {
            let space = SpaceID(item.raw)
            guard model.config.spaces.contains(space) else {
                continue
            }
            model.config.mainSpaces.insert(space)
            model.config.spacePins[space] = nil
            assigned = true
        }
        return assigned
    }
}
