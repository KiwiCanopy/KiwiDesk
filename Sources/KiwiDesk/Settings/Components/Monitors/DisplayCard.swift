import KiwiDeskCore
import SwiftUI

/// One display in the Monitors picture (#678 Phase 3, turn 13b):
/// a rectangle the size and shape of the real monitor, holding
/// the space chips that resolve to it.
///
/// **The rectangle is data, not decoration.** Its size and its
/// place come from `MonitorArrangement`, which reads the live
/// frames — so a portrait display draws portrait, a laptop under
/// a desk display draws under it, and the picture answers "which
/// one is that?" without reading a single name.
///
/// It draws as a lit PLATE on the picture's recessed well, not as
/// a card on the section's card: a display and the desk around it
/// filled with the same colour once, and the arrangement — the
/// whole point of the area — was then invisible.
///
/// Three states, three channels, because an opacity step on one
/// hue separates nothing: **main** is the badge, **selected** is
/// the border, **targeted** is a fill wash.
struct DisplayCard: View {
    @ObservedObject var model: SettingsModel
    let display: Display
    /// The area's row expansion — the same instance the census
    /// guards read, so the chips on screen are the rows the
    /// census counts.
    let rows: MonitorsFamilyRows
    /// The card's drawn size, from the arrangement. Passed in
    /// rather than measured: the chip capacity is arithmetic over
    /// it, and a capacity that waited for a layout pass could
    /// only ever clip.
    let size: CGSize
    @Binding var selection: DisplayID?
    @State private var targeted = false
    @State private var showingOverflow = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            header
            chips
            Spacer(minLength: 0)
        }
        .padding(MonitorCardChips.cardPadding)
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .topLeading
        )
        .background(plate)
        .overlay(dropWash)
        .overlay(border)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .contentShape(RoundedRectangle(cornerRadius: 6))
        .dropDestination(for: DraggableSpace.self) { items, _ in
            pin(items)
        } isTargeted: { hovering in
            targeted = hovering
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(display.name)
        .accessibilityValue(readout)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityAction(named: selectActionName) {
            toggleSelection()
        }
        .onTapGesture { toggleSelection() }
        .help(readout)
    }

    private var isMain: Bool {
        model.mainFingerprint == display.fingerprint
    }

    private var isSelected: Bool { selection == display.id }

    /// No `Divider()`: at the floor a card is barely two chip
    /// rows tall, and a rule across it spends height on chrome
    /// the capsules below already provide.
    private var header: some View {
        HStack(spacing: 4) {
            Text(display.name)
                .font(.caption)
                .bold()
                .lineLimit(1)
                .truncationMode(.tail)
            if isMain {
                BadgeChip(
                    label: L("monitor_card.main_badge", "main")
                )
            }
            Spacer(minLength: 0)
        }
        .frame(height: MonitorCardChips.headerHeight)
    }

    @ViewBuilder private var chips: some View {
        let assignments = rows.chips(on: display.fingerprint)
        if assignments.isEmpty {
            Text(L("monitor_card.drop_here", "Drop a space here"))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        } else {
            let split = MonitorCardChips.split(
                assignments,
                in: size
            )
            HStack(alignment: .top, spacing: MonitorCardChips.spacing) {
                WrapChips(split.shown) { entry in
                    chip(entry)
                }
                if split.overflow > 0 {
                    overflowChip(assignments, split.overflow)
                }
            }
        }
    }

    private func chip(_ entry: SpaceAssignment) -> some View {
        SpaceAssignmentChip(
            model: model,
            space: entry.space,
            kind: entry.kind,
            displays: rows.orderedDisplays
        )
    }

    /// The chips this card has no room for, reachable rather than
    /// clipped away — with their clear button and their menu,
    /// which are the only routes back out of a pin.
    private func overflowChip(
        _ all: [SpaceAssignment],
        _ count: Int
    ) -> some View {
        Button {
            showingOverflow = true
        } label: {
            Text(
                L("monitor_card.more_spaces", "+%1$d", count)
            )
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
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
            WrapChips(all) { entry in
                chip(entry)
            }
            .frame(width: 240)
            .padding(12)
        }
    }

    private var plate: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color(nsColor: .controlBackgroundColor))
            .shadow(radius: 0.5, y: 0.5)
    }

    /// Drop targeting is a WASH, not a heavier border: dragging
    /// onto an already-selected card has to change something, and
    /// two states sharing the border channel changed nothing.
    @ViewBuilder private var dropWash: some View {
        if targeted {
            RoundedRectangle(cornerRadius: 6)
                .fill(.tint.opacity(0.2))
        }
    }

    private var border: some View {
        RoundedRectangle(cornerRadius: 6)
            .strokeBorder(
                isSelected || targeted
                    ? AnyShapeStyle(.tint)
                    : AnyShapeStyle(
                        Color(nsColor: .separatorColor)
                    ),
                lineWidth: isSelected ? 2 : 1
            )
    }

    /// The one thing the picture cannot say by drawing: how many
    /// spaces live here, and which of them is up.
    private var readout: String {
        MonitorReadout.sentence(
            held: rows.chips(on: display.fingerprint).count,
            showing: model.showingSpace(on: display.id)
        )
    }

    private var selectActionName: String {
        isSelected
            ? L("monitors.deselect", "Hide what this holds")
            : L("monitors.select", "Show what this holds")
    }

    /// Selecting is a toggle: the readout under the picture is
    /// the only thing selection drives, so a second click on the
    /// same card puts it away rather than leaving the user
    /// hunting for what dismisses it.
    private func toggleSelection() {
        selection = isSelected ? nil : display.id
    }

    /// Pins each dropped space to this monitor's fingerprint
    /// (clearing a follows-main assignment); the footer's profile
    /// actions persist it into the profile JSON (#36).
    private func pin(_ items: [DraggableSpace]) -> Bool {
        var assigned = false
        for item in items {
            let space = SpaceID(item.raw)
            guard model.config.spaces.contains(space) else {
                continue
            }
            model.config.spacePins[space] = display.fingerprint
            model.config.mainSpaces.remove(space)
            assigned = true
        }
        return assigned
    }
}
