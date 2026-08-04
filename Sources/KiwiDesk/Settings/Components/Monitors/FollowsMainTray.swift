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
    @State private var targeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            header
            chips
            Spacer(minLength: 0)
        }
        .padding(6)
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
    }

    @ViewBuilder private var chips: some View {
        let spaces = rows.trayChips
        if spaces.isEmpty {
            Text(L("monitor_card.drop_here", "Drop a space here"))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        } else {
            WrapChips(spaces) { space in
                SpaceAssignmentChip(
                    model: model,
                    space: space,
                    kind: .main,
                    displays: rows.orderedDisplays
                )
            }
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
