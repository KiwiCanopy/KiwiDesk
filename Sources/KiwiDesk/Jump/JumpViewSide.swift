import KiwiDeskCore
import SwiftUI

/// KiwiHub's View side (#2229, #2309): the Layout, Profile and
/// KiwiVision lines, each one line under its heading, then the
/// line's Settings page and Keep. The buttons are reached by their
/// chords, never Tab, which switches side.
struct JumpViewSide: View {
    let list: ViewPickList
    let settings: TilingSettings
    let commandHeld: Bool
    let onApply: (ViewPickList.Pick) -> Void
    let onKeep: () -> Void
    let onSettings: () -> Void
    /// The pointer moved over an item.
    let onHover: (ViewPickList.Pick) -> Void

    private var selectedLine: ViewPickList.Line? { list.selection?.line }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(list.lines, id: \.self) { line in
                section(line)
            }
            buttons
        }
        .padding(.top, 8)
    }

    private func section(_ line: ViewPickList.Line) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            heading(line)
            ViewLine(
                selected: selectedLine == line ? list.selected?.pick : nil
            ) {
                if line == .layout {
                    tiles
                } else {
                    chips(line)
                }
            }
        }
    }

    private func heading(_ line: ViewPickList.Line) -> some View {
        HStack(spacing: 6) {
            Text(ViewPickText.title(line))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)
            if line == .layout {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, KeyPanelStyle.selectionInset + 10)
    }

    private var caption: String {
        if list.selection == nil, !list.query.isEmpty {
            return ViewPickText.noMatch(list.query)
        }
        return list.layout.map(LayoutPickText.caption) ?? ""
    }

    private var tiles: some View {
        let items = list.items(.layout)
        let held = commandHeld && selectedLine == .layout
        return HStack(spacing: JumpLayoutTile.spacing) {
            ForEach(Array(items.enumerated()), id: \.element.id) {
                index,
                item in
                if case .layout(let mode) = item.pick {
                    JumpLayoutTile(
                        mode: mode,
                        number: list.number(.layout, index),
                        settings: settings,
                        isSelected: isSelected(.layout, index),
                        isCurrent: item.isCurrent,
                        isDimmed: list.isDimmed(.layout, index)
                            || !item.isApplicable,
                        showsNumber: held
                            && list.number(.layout, index) != nil,
                        onActivate: { apply(item) },
                        onHover: { onHover(item.pick) }
                    )
                }
            }
        }
    }

    private func chips(_ line: ViewPickList.Line) -> some View {
        let items = list.items(line)
        return HStack(spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.element.id) {
                index,
                item in
                ViewChip(
                    item: item,
                    line: line,
                    number: list.number(line, index),
                    isSelected: isSelected(line, index),
                    isDimmed: list.isDimmed(line, index),
                    showsNumber: commandHeld && selectedLine == line,
                    onActivate: { apply(item) },
                    onHover: { onHover(item.pick) }
                )
            }
        }
        .padding(.vertical, 2)
    }

    private func isSelected(_ line: ViewPickList.Line, _ index: Int) -> Bool {
        list.selection == ViewPickList.Position(line: line, index: index)
    }

    private func apply(_ item: ViewPickList.Item) {
        if item.isApplicable { onApply(item.pick) }
    }

    private var buttons: some View {
        HStack(spacing: 8) {
            KeyPanelChordButton(
                title: ViewPickText.settings(selectedLine ?? .layout),
                chord: "⌘,"
            ) { onSettings() }
            Spacer(minLength: 0)
            if let layout = list.layout, let profile = layout.profile {
                KeyPanelChordButton(
                    title: LayoutPickText.keep(profile),
                    chord: "⌘S",
                    hint: layout.keepArmed ? nil : LayoutPickText.keepSaved
                ) { onKeep() }
                .disabled(!layout.keepArmed)
            }
        }
        .padding(.horizontal, KeyPanelStyle.selectionInset + 10)
        .padding(.bottom, 10)
    }
}
