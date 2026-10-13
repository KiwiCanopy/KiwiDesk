import KiwiDeskCore
import SwiftUI

/// The Jump to window panel (#1875): a search field, then either
/// scope (#2229) — the ranked windows with the hidden apps below
/// them, or the layout tiles — and a footer of the scope's keys.
/// Native like the shortcuts panel — system font, untinted glass.
struct JumpPanelView: View {
    @ObservedObject var model: JumpModel
    /// The live tuning the layout tiles draw.
    let settings: TilingSettings
    /// The #1307 switch's keyboard-panel leaf, read by the
    /// controller from the active profile.
    let liquidGlass: Bool
    /// This opening, which the entrance and the fade out read.
    let presence: PanelPresence
    /// The panel's width on its screen, from the controller.
    let width: CGFloat
    @FocusState private var fieldFocused: Bool
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    /// The key panels' scale (#2229 ▸ shared panel style).
    static let width: CGFloat = 640
    static let fieldHeight: CGFloat = 44
    static let headerHeight: CGFloat = 26
    static let listPadding: CGFloat = 6

    var body: some View {
        VStack(spacing: 0) {
            field
            Divider()
            scopeContent
            Divider()
            JumpFooter(scope: model.scope, overflows: overflows)
        }
        // The field stays put; only what is below it changes.
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.12),
            value: model.scope
        )
        .frame(maxHeight: .infinity, alignment: .top)
        .panelContentFade(presence)
        .frame(width: width)
        .tint(SettingsTheme.accent)
        .glassChrome(
            in: KeyPanelStyle.shape,
            enabled: liquidGlass,
            variant: .regular,
            fallback: AnyShapeStyle(.regularMaterial)
        )
        .panelEntrance(presence)
    }

    private var field: some View {
        // The glyph's frame matches the row icon's, so the field
        // text and the row titles share one leading edge.
        HStack(spacing: JumpRowView.spacing) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: JumpRowView.iconSize)
                .accessibilityHidden(true)
            TextField(
                "",
                text: Binding(
                    get: { model.query },
                    set: { model.query = $0 }
                ),
                prompt: model.field == nil
                    ? Text(model.scope.fieldName) : nil
            )
            .textFieldStyle(.plain)
            .font(.title3)
            // The selected name stands in for the typing, so the
            // typed glyphs and the caret are drawn clear under it.
            .foregroundStyle(model.field == nil ? Color.primary : Color.clear)
            .tint(model.field == nil ? SettingsTheme.accent : .clear)
            .focused($fieldFocused)
            .accessibilityLabel(model.scope.fieldName)
            .overlay(alignment: .leading) { fieldName }
            JumpScopeSwitch(model: model)
        }
        // The glyph keeps the row icons' leading edge: the
        // selection's inset plus the row's own padding.
        .padding(
            .horizontal,
            KeyPanelStyle.selectionInset + JumpRowView.padding
        )
        .frame(height: Self.fieldHeight)
        .onAppear { fieldFocused = true }
        .onChange(of: model.fieldFocusRequests) { fieldFocused = true }
        .onChange(of: model.scope) { fieldFocused = true }
    }

    /// One scope at a time, cross-faded in place.
    @ViewBuilder private var scopeContent: some View {
        ZStack(alignment: .top) {
            if model.scope == .windows {
                results.transition(.opacity)
            } else if let layouts = model.layouts {
                JumpLayoutsView(
                    list: layouts,
                    settings: settings,
                    commandHeld: model.commandHeld,
                    onApply: { model.onApply($0) },
                    onKeep: { model.onKeep() },
                    onLayoutDefaults: { model.onLayoutDefaults($0) },
                    onHover: {
                        model.hoverTile($0, pointer: NSEvent.mouseLocation)
                    }
                )
                .transition(.opacity)
            }
        }
    }

    /// The selected row's name in place of the typing — the typed
    /// letters at full ink — then what ↩ does, which never
    /// truncates; VoiceOver reads the row, not this.
    @ViewBuilder private var fieldName: some View {
        if let field = model.field {
            HStack(spacing: 0) {
                ForEach(SentenceFrame(field.frame).segments) { segment in
                    switch segment.slot {
                    case .text(let literal):
                        Text(literal)
                            .foregroundStyle(.secondary)
                            .fixedSize()
                    case .argument(1):
                        Text(field.name)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    case .argument:
                        EmptyView()
                    }
                }
            }
            .font(.title3)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    @ViewBuilder private var results: some View {
        if model.list.results.isEmpty {
            Text(model.emptyText)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .frame(height: JumpRowView.height)
                .padding(.vertical, Self.listPadding)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    rows
                        .padding(.vertical, Self.listPadding)
                        .padding(
                            .horizontal,
                            KeyPanelStyle.selectionInset
                        )
                }
                .frame(height: listHeight)
                .onChange(of: model.list.selection) { _, selection in
                    if let selection { proxy.scrollTo(selection) }
                }
            }
        }
    }

    private var rows: some View {
        let list = model.list
        let here = JumpRowText.here(of: list.snapshot)
        // Eager: a lazy stack left a row below the fold unbuilt, so
        // the selection's scroll found no row to reach.
        return VStack(spacing: 0) {
            ForEach(
                Array(list.results.enumerated()),
                id: \.offset
            ) { index, match in
                // One scroll target with its header, so a selection
                // landing on a section's first row brings the header
                // into view with it.
                VStack(spacing: 0) {
                    if let section = list.section(at: index) {
                        sectionHeader(section)
                    }
                    row(index, match, here: here)
                }
                .id(index)
            }
        }
    }

    private func row(
        _ index: Int,
        _ match: JumpSearch.Match,
        here: JumpRowText.Place?
    ) -> some View {
        let list = model.list
        return JumpRowView(
            match: match,
            icon: model.icons[match.entry.pid],
            isSelected: index == list.selection,
            number: JumpList.number(ofRow: index),
            commandHeld: model.commandHeld,
            shiftHeld: model.shiftHeld,
            wayHere: match.entry.movesHere ? here : nil,
            onActivate: { moveHere in
                model.onPick(match.entry, moveHere)
            },
            onHover: {
                model.hoverRow(index, pointer: NSEvent.mouseLocation)
            }
        )
    }

    private func sectionHeader(_ section: JumpList.Section) -> some View {
        Text(
            section == .hidden
                ? JumpRowText.hidden : JumpRowText.minimized
        )
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.secondary)
        .accessibilityAddTraits(.isHeader)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, JumpRowView.padding)
        .padding(.bottom, 3)
        .frame(height: Self.headerHeight, alignment: .bottom)
    }

    /// The list's height: what its rows take, up to `rowCap` rows.
    private var listHeight: CGFloat {
        Self.listHeight(
            rows: model.list.results.count,
            headers: model.list.sectionCount,
            rowCap: model.rowCap
        )
    }

    /// Whether the list runs past what it shows.
    private var overflows: Bool {
        Self.overflows(
            rows: model.list.results.count,
            headers: model.list.sectionCount,
            rowCap: model.rowCap
        )
    }

    static func overflows(rows: Int, headers: Int, rowCap: Int) -> Bool {
        content(rows: rows, headers: headers)
            > CGFloat(rowCap) * JumpRowView.height
    }

    private static func content(rows: Int, headers: Int) -> CGFloat {
        CGFloat(rows) * JumpRowView.height
            + CGFloat(headers) * headerHeight
    }

    static func listHeight(
        rows: Int,
        headers: Int,
        rowCap: Int
    ) -> CGFloat {
        let cap = CGFloat(rowCap) * JumpRowView.height
        return min(content(rows: rows, headers: headers), cap)
            + 2 * listPadding
    }
}
