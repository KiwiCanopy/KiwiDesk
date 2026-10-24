import AppKit
import KiwiDeskCore
import SwiftUI

/// KiwiHub, the key panel (#1875, #2265): a search field, then a
/// side (#2229) — the ranked windows with the hidden apps below
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
    /// The Shortcuts sheet's own height, which the footer's
    /// scroll cue reads; 0 on the other sides.
    @State var sheetHeight: CGFloat = 0
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    /// The key panels' scale (#2229 ▸ shared panel style).
    static let width: CGFloat = 720
    static let fieldHeight: CGFloat = 44
    /// The scope switch's cross-fade; the refit waits it out.
    static let scopeFade: TimeInterval = 0.12
    static let headerHeight: CGFloat = 26
    static let listPadding: CGFloat = 6

    var body: some View {
        // The product name around the side's, so a side announces
        // "KiwiHub, window switcher" (#2265).
        VStack(spacing: 0) { side }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(JumpScope.panelName)
            // The field stays put; only what is below it changes.
            .animation(
                reduceMotion
                    ? nil : .easeInOut(duration: Self.scopeFade),
                value: model.scope
            )
            .frame(maxHeight: .infinity, alignment: .top)
            .panelContentFade(presence)
            .frame(width: width)
            .tint(SettingsTheme.accent)
            .environment(\.kiwiHubPaint, KiwiHubPaint.of(settings))
            .panelGlassChrome(
                in: KeyPanelStyle.shape,
                glass: panelGlass,
                fallback: AnyShapeStyle(.regularMaterial)
            )
            .panelEntrance(presence)
    }

    /// The settings' panel glass, on the leaf the controller read.
    private var panelGlass: PanelGlass {
        var glass = PanelGlass(settings: settings)
        glass.enabled = liquidGlass
        return glass
    }

    private var side: some View {
        VStack(spacing: 0) {
            field
            namingCaption
            Divider()
            scopeContent
            Divider()
            footer
        }
        // The side's own name, which its shortcut row shows (#2245).
        .accessibilityElement(children: .contain)
        .accessibilityLabel(model.scope.panelName)
    }

    private var field: some View {
        // The glyph's frame matches the row icon's, so the field
        // text and the row titles share one leading edge.
        HStack(spacing: JumpRowView.spacing) {
            Image(systemName: model.isNaming ? "plus" : "magnifyingglass")
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
                // The field shows only the typing; the selection is
                // the row or tile below (#2246).
                prompt: Text(fieldName)
            )
            .textFieldStyle(.plain)
            .font(.title3)
            .tint(SettingsTheme.accent)
            .focused($fieldFocused)
            .accessibilityLabel(fieldName)
            .accessibilityHint(namingLine ?? "")
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
        .onChange(of: model.fieldSelectAllRequests) { selectFieldText() }
    }

    /// The pre-filled name is selected, so typing replaces it. The
    /// field editor selects a turn later, once the field holds
    /// the new text.
    private func selectFieldText() {
        fieldFocused = true
        // The panel's own field editor, never whatever responds.
        DispatchQueue.main.async {
            (NSApp.keyWindow?.firstResponder as? NSText)?.selectAll(nil)
        }
    }

    /// One scope at a time, cross-faded in place.
    @ViewBuilder private var scopeContent: some View {
        ZStack(alignment: .top) {
            if model.scope == .windows {
                results.transition(.opacity)
            } else if model.scope == .shortcuts, let sheet = model.shortcuts {
                JumpShortcutsView(
                    sheet: sheet,
                    scroll: model.sheetScroll,
                    maxHeight: model.sheetCap
                )
                .transition(.opacity)
            } else if let view = model.view {
                JumpViewSide(
                    list: view,
                    settings: settings,
                    commandHeld: model.commandHeld,
                    hover: model.hover,
                    onApply: { model.clickItem($0) },
                    onHover: {
                        model.hoverItem($0, pointer: model.currentPointer())
                    },
                    onHoverEnd: { model.endHover(.item($0)) }
                )
                .transition(.opacity)
            }
        }
        .onPreferenceChange(SheetHeightKey.self) { sheetHeight = $0 }
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
            isLifted: JumpHover.lifts(
                .row(index),
                hover: model.hover,
                selected: index == list.selection,
                clickable: true
            ),
            number: JumpList.number(ofRow: index),
            commandHeld: model.commandHeld,
            shiftHeld: model.shiftHeld,
            wayHere: match.entry.movesHere ? here : nil,
            onActivate: { moveHere in
                model.clickRow(index, moveHere: moveHere)
            },
            onHover: {
                model.hoverRow(index, pointer: model.currentPointer())
            },
            onHoverEnd: { model.endHover(.row(index)) }
        )
    }

    private func sectionHeader(_ section: JumpList.Section) -> some View {
        Text(JumpRowText.header(section))
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

    /// Whether the Windows list runs past what it shows.
    var listOverflows: Bool {
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
