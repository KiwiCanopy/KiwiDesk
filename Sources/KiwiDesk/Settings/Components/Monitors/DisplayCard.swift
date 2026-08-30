import KiwiDeskCore
import SwiftUI

/// Display card in monitors arrangement preview (#678, #758).
struct DisplayCard: View {
    @ObservedObject var model: SettingsModel
    let display: Display
    /// Row expansion from census.
    let rows: MonitorsFamilyRows
    /// Scaled dimensions from arrangement.
    let size: CGSize
    @Binding var selection: DisplayID?
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
        .background(plate)
        .overlay(dropWash)
        .overlay(border)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        // Main display accent glow (#758, ui-designer 2026-08-09).
        .compositingGroup()
        .shadow(
            color: isMain
                ? SettingsTheme.accent.opacity(0.55)
                : .clear,
            radius: isMain ? 6 : 0
        )
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

    /// Checked by ID rather than fingerprint for duplicate screens
    /// (2026-08-04).
    private var isMain: Bool {
        model.mainDisplay?.id == display.id
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
            Text(L("monitor_card.drop_here", "Drop a Space here"))
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
            WrapChips(all) { entry in
                chip(entry)
            }
            .frame(width: 240)
            .padding(12)
        }
    }

    private var plate: some View {
        RoundedRectangle(cornerRadius: 6)
            // The soft green, not the white card surface: a
            // wall of white screens on the well glared, and
            // the strengthened rest border now carries the
            // card/well separation (owner, 2026-08-09 — the
            // prototype's own colouring).
            .fill(SettingsTheme.sunken)
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
                        SettingsTheme.ink3.opacity(0.5)
                    ),
                lineWidth: isSelected
                    ? SettingsTheme.monitorCardStrokeSelected
                    : SettingsTheme.monitorCardStroke
            )
    }

    /// Readout sentence describing assigned and showing spaces.
    private var readout: String {
        MonitorReadout.sentence(
            held: rows.held(on: display, isMain: isMain),
            showing: model.showingSpace(on: display.id)
        )
    }

    private var selectActionName: String {
        isSelected
            ? L(
                "monitors.deselect",
                "Hide the Spaces on this display"
            )
            : L(
                "monitors.select",
                "Show the Spaces on this display"
            )
    }

    private func toggleSelection() {
        selection = isSelected ? nil : display.id
    }

    /// Pins dropped spaces to monitor fingerprint (#36).
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
