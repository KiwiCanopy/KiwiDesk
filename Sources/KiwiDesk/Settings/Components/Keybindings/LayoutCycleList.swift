import AppKit
import KiwiDeskCore
import SwiftUI

/// The layout cycle's popover (#2673, reversing #453's inline
/// list): all seven layouts, the cycle's in order with a drag
/// handle, the rest below in the Layout menu's order. A tick adds
/// a layout at the end, an untick takes it out; at two the ticked
/// boxes grey, the row's `?` saying why. Move Up / Move Down ride
/// `rowActions` on each ticked box, which holds keyboard focus.
struct LayoutCycleList: View {
    @ObservedObject var model: SettingsModel
    @State private var dragOrder: [LayoutMode]?
    @State private var dragged: LayoutMode?
    @State private var rowFrames: [LayoutMode: CGRect] = [:]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let listSpace = "layoutCycleList"
    static let rowHeight: CGFloat = 28

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(cycle, id: \.self) { mode in
                item(mode, in: true)
            }
            Divider().padding(.vertical, 4)
            ForEach(model.modeCycleAddable, id: \.self) { mode in
                item(mode, in: false)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .coordinateSpace(name: Self.listSpace)
        .onPreferenceChange(ItemFrames.self) { rowFrames = $0 }
        .frame(width: SettingsMetrics.cycleListWidth, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(LayoutCycleWords.title)
    }

    private var cycle: [LayoutMode] {
        dragOrder ?? model.config.modeCycle
    }

    private func item(_ mode: LayoutMode, in cycle: Bool) -> some View {
        HStack(spacing: 6) {
            if cycle {
                handle(mode)
            } else {
                Color.clear.frame(width: 20, height: 22)
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

    @ViewBuilder private func box(_ mode: LayoutMode, in cycle: Bool)
        -> some View
    {
        let toggle = Toggle(
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
                    .foregroundStyle(SettingsTheme.ink)
            }
        }
        .toggleStyle(.checkbox)
        .accessibilityLabel(label(mode))
        if cycle {
            toggle
                .disabled(!model.modeCycleCanRemove)
                .rowActions { actions(mode) }
        } else {
            toggle
        }
    }

    /// The layout's name and, in the cycle, its place there.
    private func label(_ mode: LayoutMode) -> String {
        let list = model.config.modeCycle
        guard let index = list.firstIndex(of: mode) else {
            return mode.displayName
        }
        return mode.displayName + ", "
            + LayoutCycleWords.position(index, of: list.count)
    }

    private func tick(_ mode: LayoutMode, _ on: Bool) {
        withAnimation(reduceMotion ? nil : SpacesSection.reorderSpring) {
            if on {
                model.addCycleMode(mode)
            } else {
                model.removeCycleMode(mode)
            }
        }
    }

    @ViewBuilder private func actions(_ mode: LayoutMode) -> some View {
        let index = model.config.modeCycle.firstIndex(of: mode)
        Button(LayoutCycleWords.moveUp) {
            model.stepCycleMode(mode, by: -1)
        }
        .disabled(index == 0)
        Button(LayoutCycleWords.moveDown) {
            model.stepCycleMode(mode, by: 1)
        }
        .disabled(index == model.config.modeCycle.count - 1)
    }

    // MARK: - Drag

    /// The Spaces list's handle (`SpacesSection+Drag`), locked to
    /// the vertical axis by reading the pointer's y alone; cursor
    /// changes use `set()`, never push/pop (gui.md).
    private func handle(_ mode: LayoutMode) -> some View {
        Image(systemName: "line.3.horizontal")
            .foregroundStyle(SettingsTheme.ink2)
            .frame(width: 20, height: 22)
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
        withAnimation(reduceMotion ? nil : SpacesSection.reorderSpring) {
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
