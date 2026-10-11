import AppKit
import KiwiDeskCore
import SwiftUI

/// The layout cycle's editable list (#453): the chosen layouts in
/// cycle order, each with its symbol; a vertical handle drag and
/// Move Up / Move Down / Remove through `rowActions` reorder and
/// trim it, ＋ offers the layouts not in it and − removes the
/// selected one. ＋ greys with all seven listed and − at two, the
/// row's `?` saying why.
struct LayoutCycleList: View {
    @ObservedObject var model: SettingsModel
    @State private var selected: LayoutMode?
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
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(SettingsTheme.sunken)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(SettingsTheme.hairline)
        )
        .frame(maxWidth: 320, alignment: .leading)
    }

    private var displayed: [LayoutMode] {
        dragOrder ?? model.config.modeCycle
    }

    private func item(_ mode: LayoutMode) -> some View {
        HStack(spacing: 8) {
            handle(mode)
            Image(systemName: mode.symbol)
                .frame(width: 18)
                .foregroundStyle(SettingsTheme.ink2)
                .accessibilityHidden(true)
            Text(mode.displayName)
                .foregroundStyle(SettingsTheme.ink)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            selected == mode ? SettingsTheme.chipPressed : Color.clear
        )
        .contentShape(Rectangle())
        .onTapGesture { selected = mode }
        .background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: ItemFrames.self,
                    value: [mode: proxy.frame(in: .named(Self.listSpace))]
                )
            }
        )
        .accessibilityElement(children: .combine)
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
                    selected = mode
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
        .disabled(model.modeCycleAddable.isEmpty)
        .help(LayoutCycleWords.add)
    }

    private func remove(_ mode: LayoutMode) {
        model.removeCycleMode(mode)
        if selected == mode { selected = nil }
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
            .onEnded { _ in
                NSCursor.arrow.set()
                if let order = dragOrder { model.reorderCycle(order) }
                dragOrder = nil
                dragged = nil
            }
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
