import AppKit
import KiwiDeskCore
import SwiftUI

/// The layout cycle's popover (#2673): all seven layouts, the
/// cycle's in order with a drag handle, the rest below in the
/// Layout menu's order. A tick adds a layout at the end, an untick
/// takes it out; at two the ticked boxes grey, the sentence under
/// them saying why. Move Up / Move Down ride `rowActions` on every
/// row, greyed on an unticked one; a ticked row holds keyboard
/// focus itself while its box is greyed, and a click focuses it
/// without a ring (#991).
struct LayoutCycleList: View {
    @ObservedObject var model: SettingsModel
    @State private var dragOrder: [LayoutMode]?
    @State private var dragged: LayoutMode?
    @State private var rowFrames: [LayoutMode: CGRect] = [:]
    @FocusState private var focused: LayoutMode?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let listSpace = "layoutCycleList"
    static let rowHeight: CGFloat = 28
    private static let handleWidth: CGFloat = 20

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // One ForEach, so a tick moves a row without rebuilding
            // it and its checkbox keeps keyboard focus.
            ForEach(cycle + addable, id: \.self) { mode in
                item(mode)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .coordinateSpace(name: Self.listSpace)
        .onPreferenceChange(ItemFrames.self) { rowFrames = $0 }
        .onChange(of: focused) { _, now in
            // A click focuses a greyed row; it does not ring it.
            guard now != nil else { return }
            if ClickBornFocus.isClickBorn(focusMayBeADescendant: false) {
                focused = nil
            }
        }
        .frame(width: SettingsMetrics.cycleListWidth, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(LayoutCycleWords.title)
    }

    private var cycle: [LayoutMode] {
        dragOrder ?? model.config.modeCycle
    }

    /// The unticked layouts, read off `cycle` so a config change
    /// mid-drag cannot draw one layout twice.
    private var addable: [LayoutMode] {
        SettingsModel.cycleAddable(besides: cycle)
    }

    /// Every row takes the same modifiers whether ticked or not,
    /// so its identity survives a tick (#2673).
    private func item(_ mode: LayoutMode) -> some View {
        let ticked = cycle.contains(mode)
        return VStack(alignment: .leading, spacing: 0) {
            if mode == addable.first {
                Divider().padding(.vertical, 4)
            }
            // A greyed box takes no focus, so the row holds it then
            // for the row menu's chord.
            row(mode, in: ticked)
                .focusable(held(mode))
                .focused($focused, equals: mode)
                // One element, so VoiceOver finds the row menu on it.
                .accessibilityElement(children: .combine)
                .rowActions { actions(mode) }
            if held(mode), mode == cycle.last {
                // The greyed boxes' reason, drawn outside their GreyOut.
                Text(LayoutCycleWords.minimum)
                    .font(.caption)
                    .foregroundStyle(SettingsTheme.ink3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, Self.handleWidth + 6)
            }
        }
    }

    /// A ticked layout the cycle cannot lose: its box greys.
    private func held(_ mode: LayoutMode) -> Bool {
        !model.modeCycleCanRemove && cycle.contains(mode)
    }

    private func row(_ mode: LayoutMode, in cycle: Bool) -> some View {
        HStack(spacing: 6) {
            if cycle {
                handle(mode)
            } else {
                Color.clear.frame(width: Self.handleWidth, height: 22)
            }
            box(mode, in: cycle)
            Spacer(minLength: 0)
        }
        .frame(height: Self.rowHeight)
        .contentShape(Rectangle())
        .background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: ItemFrames.self,
                    value: cycle
                        ? [mode: proxy.frame(in: .named(Self.listSpace))]
                        : [:]
                )
            }
        )
    }

    private func box(_ mode: LayoutMode, in cycle: Bool) -> some View {
        Toggle(
            isOn: Binding(
                get: { cycle },
                set: { on in tick(mode, on) }
            )
        ) {
            HStack(spacing: 6) {
                Image(systemName: mode.symbol)
                    .frame(width: 18)
                    .foregroundStyle(SettingsTheme.ink2)
                    .accessibilityHidden(true)
                Text(mode.displayName)
            }
        }
        .toggleStyle(.checkbox)
        .accessibilityLabel(label(mode))
        .modifier(
            GreyOut(active: held(mode), help: LayoutCycleWords.minimum)
        )
    }

    /// The layout's name and, in the cycle, its place there.
    private func label(_ mode: LayoutMode) -> String {
        let list = model.config.modeCycle
        guard let index = list.firstIndex(of: mode) else {
            return mode.displayName
        }
        return LayoutCycleWords.placed(
            mode.displayName,
            index,
            of: list.count
        )
    }

    private func tick(_ mode: LayoutMode, _ on: Bool) {
        withAnimation(reduceMotion ? nil : SpaceReorder.spring) {
            if on {
                model.addCycleMode(mode)
            } else {
                model.removeCycleMode(mode)
            }
        }
    }

    @ViewBuilder private func actions(_ mode: LayoutMode) -> some View {
        // An unticked row has no place to move from: both grey.
        let list = model.config.modeCycle
        let index = list.firstIndex(of: mode)
        Button(LayoutCycleWords.moveUp) {
            model.stepCycleMode(mode, by: -1)
        }
        .disabled(index == nil || index == 0)
        Button(LayoutCycleWords.moveDown) {
            model.stepCycleMode(mode, by: 1)
        }
        .disabled(index == nil || index == list.count - 1)
    }

    // MARK: - Drag

    /// The Spaces list's handle (`SpacesSection+Drag`), locked to
    /// the vertical axis by reading the pointer's y alone; cursor
    /// changes use `set()`, never push/pop (gui.md).
    private func handle(_ mode: LayoutMode) -> some View {
        Image(systemName: "line.3.horizontal")
            .foregroundStyle(SettingsTheme.ink2)
            .frame(width: Self.handleWidth, height: 22)
            .contentShape(Rectangle())
            .help(LayoutCycleWords.dragHelp)
            .accessibilityHidden(true)
            .onHover { inside in
                guard dragged == nil else { return }
                (inside ? NSCursor.openHand : .arrow).set()
            }
            .onDisappear {
                // A cancelled drag (the window resigning key) skips
                // onEnded, and a handle removed under the pointer
                // never sends the balancing hover: commit and reset
                // here, as the Spaces list does.
                guard dragged == mode else { return }
                endDrag()
            }
            .gesture(drag(mode))
    }

    private func drag(_ mode: LayoutMode) -> some Gesture {
        DragGesture(coordinateSpace: .named(Self.listSpace))
            .onChanged { value in
                if dragged == nil {
                    dragged = mode
                    dragOrder = model.config.modeCycle
                    NSCursor.closedHand.set()
                }
                retarget(mode, at: value.location.y)
            }
            .onEnded { _ in endDrag() }
    }

    /// Commits the dragged order once and resets the drag.
    private func endDrag() {
        NSCursor.arrow.set()
        if let order = dragOrder { model.reorderCycle(order) }
        dragOrder = nil
        dragged = nil
    }

    /// Swaps once the pointer crosses the candidate's midpoint, as
    /// the Spaces list does, so a swap never oscillates.
    private func retarget(_ mode: LayoutMode, at y: CGFloat) {
        var order = dragOrder ?? model.config.modeCycle
        guard
            let candidate = rowFrames.first(where: {
                $0.key != mode && $0.value.minY <= y
                    && y <= $0.value.maxY
            }),
            let from = order.firstIndex(of: mode),
            let to = order.firstIndex(of: candidate.key),
            to > from
                ? y >= candidate.value.midY
                : y <= candidate.value.midY
        else { return }
        withAnimation(reduceMotion ? nil : SpaceReorder.spring) {
            order.move(
                fromOffsets: IndexSet(integer: from),
                toOffset: to > from ? to + 1 : to
            )
            dragOrder = order
        }
    }

    private struct ItemFrames: PreferenceKey {
        static var defaultValue: [LayoutMode: CGRect] { [:] }
        static func reduce(
            value: inout [LayoutMode: CGRect],
            nextValue: () -> [LayoutMode: CGRect]
        ) {
            value.merge(nextValue()) { _, new in new }
        }
    }
}
