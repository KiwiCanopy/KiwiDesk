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
/// hue separates nothing: **main** is the badge (plus an accent
/// glow, which is decoration — the badge is the answer, since a
/// glow is hue alone and dies under colour-vision deficiency,
/// #758), **selected** is the border, **targeted** is a fill
/// wash.
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
        // TWO children and one gap, laid out with the constant
        // the capacity arithmetic subtracts. The trailing
        // `Spacer` this used to carry was a third child — so a
        // second gap the arithmetic did not know about — and the
        // frame below already pins the content to the top
        // (code review, 2026-08-04).
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
        // The main display's glow — OUTSIDE the clip, so it can
        // spill past the card's edge onto the well. Decoration
        // only; the header's "main" badge stays the answer
        // (#758). The compositing group is load-bearing:
        // `.shadow` shadows every drawing primitive separately,
        // so without flattening first the main card's text,
        // chips and strokes each grow their own green halo
        // while the silhouette gets none (ui-designer,
        // 2026-08-09).
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

    /// By display ID, not by fingerprint: two identical monitors
    /// share a fingerprint, so a fingerprint comparison drew the
    /// "main" badge on BOTH cards while the tray hung off one —
    /// the two answers to one question that
    /// `SettingsModel.mainDisplay` exists to prevent (code
    /// review, 2026-08-04).
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
                    // ink3, not the hairline: on the sunken
                    // well the hairline sits within a few
                    // points of the ground and the resting
                    // cards read borderless — every display
                    // owes a visible frame, the main one keeps
                    // the tint on top (owner, 2026-08-09).
                    : AnyShapeStyle(
                        SettingsTheme.ink3.opacity(0.5)
                    ),
                lineWidth: isSelected
                    ? SettingsTheme.monitorCardStrokeSelected
                    : SettingsTheme.monitorCardStroke
            )
    }

    /// The one thing the picture cannot say by drawing: how many
    /// spaces live here, and which of them is up.
    private var readout: String {
        MonitorReadout.sentence(
            held: rows.held(on: display, isMain: isMain),
            showing: model.showingSpace(on: display.id)
        )
    }

    /// Named with its object, not deictically: these reach a
    /// translator as bare worksheet lines with no element label
    /// and no screen, and "what this holds" needs an explicit
    /// noun in most target languages (localization audit,
    /// 2026-08-04).
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
