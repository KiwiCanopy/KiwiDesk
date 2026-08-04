import KiwiDeskCore
import SwiftUI

/// The dashed **Follows main display** tray (#36, redrawn in
/// #678 Phase 3 turn 13b): a space dropped here tracks whichever
/// display is currently main instead of freezing a fingerprint.
///
/// It is deliberately NOT a fourth card in a row of cards. A
/// space that follows main is a statement about the MAIN display,
/// so the tray hangs off that display's rectangle and moves with
/// the "main" badge — `MonitorTray` owns where it lands. Dashed
/// rather than solid because the thing it represents is a role,
/// not a piece of hardware: there is no rectangle on the desk
/// that corresponds to it.
struct FollowsMainTray: View {
    @ObservedObject var model: SettingsModel
    let rows: MonitorsFamilyRows
    /// The tray's drawn size, from the arrangement — it holds
    /// chips in a fixed band exactly as a card does, so it takes
    /// the same overflow arithmetic. Without it the tray was the
    /// one unbounded chip container left, clipping every space
    /// past its first row along with that space's clear button
    /// and menu (architect review, 2026-08-04).
    let size: CGSize
    @State private var targeted = false
    @State private var showingOverflow = false

    var body: some View {
        // Two children, one gap, the shared constant — the same
        // shape the card holds, since the tray runs the card's
        // capacity arithmetic.
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
        // NO plate. A display is a lit surface on the picture's
        // well; the tray is a ROLE, and giving it the same fill,
        // radius and stroke made it read as a fourth monitor
        // hovering above the desk. It carries a wash only while a
        // drop is over it, which is the same targeting channel
        // the cards use.
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
        // Framed, so the height the chip arithmetic subtracts is
        // TRUE of this header rather than an estimate of an
        // unsized `.caption2` (code review, 2026-08-04).
        .frame(height: MonitorCardChips.trayHeaderHeight)
    }

    @ViewBuilder private var chips: some View {
        let spaces = rows.trayChips
        if spaces.isEmpty {
            Text(L("monitor_card.drop_here", "Drop a space here"))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        } else {
            // The tray's header is unsized `.caption2`, shorter
            // than the card's, so it passes its own rather than
            // inheriting a number that only happens to be close.
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

    /// The chips the tray has no room for, reachable rather than
    /// clipped away — the same offer the display cards make.
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
                "%1$d more spaces on this display",
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
