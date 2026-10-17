import AppKit
import KiwiDeskCore
import SwiftUI

/// The layout cycle's editable list (#453): the chosen layouts in
/// cycle order, each with its symbol; a vertical handle drag and
/// Move Up / Move Down / Remove through `rowActions` reorder and
/// trim it, ＋ offers the layouts not in it and − (or Delete)
/// removes the selected one. ＋ greys with all seven listed and −
/// at two, the row's `?` saying why. Each item holds keyboard
/// focus, which selects it, so − and the row menu's chord reach a
/// keyboard user; a click selects without a focus ring (#991).
struct LayoutCycleList: View {
    @ObservedObject var model: SettingsModel
    @State private var picked: LayoutMode?
    @FocusState private var focused: LayoutMode?
    @State private var dragOrder: [LayoutMode]?
    @State private var dragged: LayoutMode?
    @State private var rowFrames: [LayoutMode: CGRect] = [:]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let listSpace = "layoutCycleList"

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(displayed, id: \.self) { mode in
                item(mode)
            }
            SettingsTheme.hairline.frame(height: 1)
            bar
        }
        .coordinateSpace(name: Self.listSpace)
        .onPreferenceChange(ItemFrames.self) { rowFrames = $0 }
        .onChange(of: focused) { _, now in
            guard let now else { return }
            picked = now
            // A click selects; it does not ring the item.
            if ClickBornFocus.isClickBorn(focusMayBeADescendant: false) {
                focused = nil
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(SettingsTheme.sunken)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(SettingsTheme.hairline)
        )
        .frame(maxWidth: SettingsMetrics.cycleListWidth, alignment: .leading)
    }

    private var displayed: [LayoutMode] {
        dragOrder ?? model.config.modeCycle
    }

    /// The selection, while it is still in the list — a Revert or a
    /// reload can take it out from under the row.
    private var selected: LayoutMode? {
        picked.flatMap { model.config.modeCycle.contains($0) ? $0 : nil }
    }

    /// Whether the list holds keyboard focus — a click selects
    /// without it, so the accent row is the keyboard's alone.
    private var listFocused: Bool { focused != nil }

    /// The selected row is the accent while the list holds focus
    /// and the grey selection otherwise, as a macOS list draws it.
    private func rowFill(_ mode: LayoutMode) -> Color {
        guard selected == mode else { return .clear }
        return listFocused ? SettingsTheme.accent : SettingsTheme.rowSelected
    }

    private func item(_ mode: LayoutMode) -> some View {
        let onAccent = selected == mode && listFocused
        return HStack(spacing: 8) {
            handle(mode)
            Image(systemName: mode.symbol)
                .frame(width: 18)
                .foregroundStyle(
                    onAccent
                        ? SettingsTheme.accentInkSecondary
                        : SettingsTheme.ink2
                )
                .accessibilityHidden(true)
            Text(mode.displayName)
                .foregroundStyle(
                    onAccent ? SettingsTheme.accentInk : SettingsTheme.ink
                )
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(rowFill(mode))
        .contentShape(Rectangle())
        .onTapGesture { picked = mode }
        .focusable()
        .focused($focused, equals: mode)
        .onDeleteCommand { remove(mode) }
        .background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: ItemFrames.self,
                    value: [mode: proxy.frame(in: .named(Self.listSpace))]
                )
            }
        )
        .accessibilityElement(children: .combine)
        .accessibilityValue(position(of: mode))
        .accessibilityAddTraits(selected == mode ? .isSelected : [])
        .rowActions { actions(mode) }
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
        Divider()
        Button(LayoutCycleWords.remove) { remove(mode) }
            .disabled(!model.modeCycleCanRemove)
    }

    private var bar: some View {
        HStack(spacing: 0) {
            addMenu
            Divider().frame(height: 16)
            Button {
                if let selected { remove(selected) }
            } label: {
                Label(LayoutCycleWords.remove, systemImage: "minus")
                    .labelStyle(.iconOnly)
                    .frame(width: 24, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(SettingsTheme.ink2)
            .iconHoverChip(padding: 0)
            .disabled(selected == nil || !model.modeCycleCanRemove)
            .help(LayoutCycleWords.remove)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
    }

    private var addMenu: some View {
        Menu {
            ForEach(model.modeCycleAddable, id: \.self) { mode in
                Button {
                    model.addCycleMode(mode)
                    picked = mode
                } label: {
                    Label(mode.displayName, systemImage: mode.symbol)
                }
            }
        } label: {
            // Named by its own label, so VoiceOver keeps the menu's
            // derived announcement (#812).
            Label(LayoutCycleWords.add, systemImage: "plus")
                .labelStyle(.iconOnly)
                .frame(width: 24, height: 20)
        }
        .menuStyle(.borderlessButton)
        .neutralMenuLabel()
        .menuIndicator(.hidden)
        .fixedSize()
        .iconHoverChip()
        .disabled(model.modeCycleAddable.isEmpty)
        .help(LayoutCycleWords.add)
    }

    private func remove(_ mode: LayoutMode) {
        model.removeCycleMode(mode)
    }

    private func position(of mode: LayoutMode) -> String {
        let list = model.config.modeCycle
        guard let index = list.firstIndex(of: mode) else { return "" }
        return LayoutCycleWords.position(index, of: list.count)
    }

    // MARK: - Drag

    /// The Spaces list's handle (`SpacesSection+Drag`), locked to
    /// the vertical axis by reading the pointer's y alone; cursor
    /// changes use `set()`, never push/pop (gui.md).
    private func handle(_ mode: LayoutMode) -> some View {
        Image(systemName: "line.3.horizontal")
            .foregroundStyle(
                selected == mode && listFocused
                    ? SettingsTheme.accentInkSecondary
                    : SettingsTheme.ink2
            )
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
