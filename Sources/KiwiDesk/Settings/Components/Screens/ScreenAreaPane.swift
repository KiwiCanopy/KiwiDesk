import Foundation
import KiwiDeskCore
import SwiftUI

/// One area of a screen card (#3517 ruling 24), or a whole
/// screen's one pane: the unit of click, drop, readout and
/// VoiceOver. The card owns the plate, outline, glow and rise.
struct ScreenAreaPane: View {
    @ObservedObject var model: SettingsModel
    let display: Display
    let rows: ScreensFamilyRows
    /// The area's id, nil while the screen is whole.
    let area: Int?
    /// The key a pin to this pane stores.
    let key: String
    /// The first pane in reading order carries the screen's name.
    let leads: Bool
    let size: CGSize
    let corners: RectangleCornerRadii
    /// The area giving way in an open Adjust… popover.
    let givesWay: Bool
    @Binding var selection: ScreenSelection?
    let act: (ScreenAreaAction) -> Void
    /// A menu's Split or Merge landed here: take the focus.
    let focusRequest: ScreenSelection?
    /// Tells the card a dragged Space came over this pane or left.
    let onTargeted: (Bool) -> Void
    @State private var targeted = false
    @State private var showingOverflow = false
    @State private var hovering = false
    @FocusState private var focused: Bool
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: ScreenCardChips.stackSpacing
        ) {
            header
            chips
        }
        .padding(ScreenCardChips.cardPadding)
        .frame(
            width: size.width,
            height: size.height,
            alignment: .topLeading
        )
        // A ground signal under the chips, never over them (#1240).
        .background(dropWash)
        .overlay(edge)
        .overlay(
            SelectionStroke(
                selected: isSelected,
                shape: shape,
                style: .tint,
                lineWidth: SettingsTheme.screenCardStrokeSelected
            )
        )
        .contentShape(shape)
        .onHover { hovering = $0 }
        .dropDestination(for: DraggableSpace.self) { items, _ in
            pin(items)
        } isTargeted: { inside in
            targeted = inside
            onTargeted(inside)
        }
        .onTapGesture { toggleSelection() }
        // A pane is a stop on the keyboard path: Space or Return
        // selects it, as a click does, and its menu takes ⌃. there.
        .focusable()
        .focused($focused)
        // A click must not ring the pane (#996): its chips and the
        // overflow button are focusable inside it.
        .onChange(of: focused) { _, now in
            guard now,
                ClickBornFocus.isClickBorn(focusMayBeADescendant: true)
            else { return }
            focused = false
        }
        .onChange(of: focusRequest) { _, request in
            if request == ScreenSelection(display: display.id, area: area) {
                focused = true
            }
        }
        .onKeyPress(.space) {
            toggleSelection()
            return .handled
        }
        .onKeyPress(.return) {
            toggleSelection()
            return .handled
        }
        // The full name too: a narrow first area truncates it.
        .help(
            isSplit
                ? model.areaName(area, on: display) + "\n" + readout : readout
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(model.areaName(area, on: display))
        .accessibilityValue(readout)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityAction(named: selectActionName) {
            toggleSelection()
        }
        .modifier(
            AreaMenu(
                model: model,
                display: display,
                area: area,
                act: act
            )
        )
    }

    private var shape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(cornerRadii: corners)
    }

    private var isSplit: Bool { area != nil }

    private var isMain: Bool { model.mainDisplay?.id == display.id }

    private var isSelected: Bool {
        selection == ScreenSelection(display: display.id, area: area)
    }

    /// The pane's header: a whole screen's name, else the area's
    /// label, the first area in reading order carrying the screen's
    /// name and badge through the one " – " frame, where the name
    /// truncates first (ruling 27).
    private var header: some View {
        HStack(spacing: 0) {
            let screen = model.screenLabel(display)
            let label = area.flatMap { model.areaLabel($0, on: display) }
            if leads, let label {
                ForEach(SentenceFrame(ScreenAreaWords.nameFrame).segments) {
                    segment in
                    switch segment.slot {
                    case .argument(1):
                        Text(screen)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    case .argument(2):
                        Text(label).fixedSize().layoutPriority(1)
                    case .text(let literal):
                        Text(literal).fixedSize().layoutPriority(1)
                    case .argument:
                        EmptyView()
                    }
                }
            } else {
                Text(label ?? screen)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            if leads && isMain {
                BadgeChip(
                    label: L("monitor_card.main_badge", "main")
                )
                .padding(.leading, 4)
                .layoutPriority(2)
            }
            Spacer(minLength: 0)
        }
        .font(.caption)
        .bold()
        .frame(height: ScreenCardChips.headerHeight)
        .accessibilityHidden(true)
    }

    @ViewBuilder private var chips: some View {
        let assignments = rows.chips(on: key)
        if assignments.isEmpty {
            Text(L("monitor_card.drop_here", "Drop a Space here"))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        } else {
            let split = ScreenCardChips.split(assignments, in: size)
            HStack(alignment: .top, spacing: ScreenCardChips.spacing) {
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

    /// The chips this pane has no room for, reachable rather than
    /// clipped away, with their clear button and menu.
    private func overflowChip(
        _ all: [SpaceAssignment],
        _ count: Int
    ) -> some View {
        Button {
            showingOverflow = true
        } label: {
            Text(L("monitor_card.more_spaces", "+%1$d", count))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(SettingsTheme.ink)
                .lineLimit(1)
                .frame(width: ScreenCardChips.markerWidth)
                .padding(.vertical, 3)
                .hoverHighlight(
                    cornerRadius: ScreenCardChips.chipHeight / 2,
                    padding: 0
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            isSplit
                ? L(
                    "monitor_card.more_spaces.area.axlabel",
                    "%1$d more Spaces in this area",
                    count
                )
                : L(
                    "monitor_card.more_spaces.axlabel",
                    "%1$d more Spaces on this screen",
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

    @ViewBuilder private var dropWash: some View {
        if targeted {
            shape.fill(.tint.opacity(0.2))
        }
    }

    /// The drop's tint edge, else the hover edge on a split card —
    /// where it says which area a click will hit — and on the area
    /// giving way in Adjust…; a whole screen's hover is the card's.
    @ViewBuilder private var edge: some View {
        if targeted {
            shape.strokeBorder(
                .tint,
                lineWidth: SettingsTheme.screenCardStroke
            )
        } else if isSplit, (hovering && isEnabled) || givesWay {
            shape.strokeBorder(
                SettingsTheme.hoverEdge,
                lineWidth: SettingsTheme.hoverEdgeStroke
            )
        }
    }

    /// What the pane holds and the Space its area shows (#3517).
    private var readout: String {
        ScreenReadout.sentence(
            held: rows.held(on: key, isMain: isMain),
            showing: model.showingSpace(inArea: key, on: display.id)
        )
    }

    private var selectActionName: String {
        switch (isSelected, isSplit) {
        case (true, false):
            L("monitors.deselect", "Deselect this screen")
        case (false, false):
            L("monitors.select", "Select this screen to edit it")
        case (true, true):
            L("monitors.area_deselect", "Deselect this area")
        case (false, true):
            L("monitors.area_select", "Select this area to edit it")
        }
    }

    private func toggleSelection() {
        let mine = ScreenSelection(display: display.id, area: area)
        selection = isSelected ? nil : mine
    }

    /// Pins dropped Spaces to this pane's key (#36, #3517).
    private func pin(_ items: [DraggableSpace]) -> Bool {
        var assigned = false
        for item in items {
            let space = SpaceID(item.raw)
            guard model.config.spaces.contains(space) else {
                continue
            }
            model.place(space, .screen(key))
            assigned = true
        }
        return assigned
    }
}
