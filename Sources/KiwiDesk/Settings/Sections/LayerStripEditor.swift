import KiwiDeskCore
import SwiftUI

/// The Layers card's one row (#3263): the layer chips, a hairline,
/// then + and ✎ at the trailing edge. + and ✎ open one editor
/// popover; every chip carries Edit…, Rename… and Delete… through
/// `rowActions`, greyed on `default`. A delete presents from here.
struct LayerStripEditor: View {
    @ObservedObject var model: SettingsModel
    @Binding var selected: String
    @State private var editor: LayerEditorRequest?
    @State private var deleteRequest: LayerDeleteRequest?
    /// Each chip's drawn width, which the strip's run reads.
    @State private var chipWidths: [String: CGFloat] = [:]
    /// Keyboard focus target following layer deletion (#816).
    @FocusState private var focusedChip: String?

    private static let gap: CGFloat = 6

    var body: some View {
        // Top-aligned, the trailing group given the strip's top
        // room, so + and ✎ sit level with the chips in both shapes.
        HStack(alignment: .top, spacing: 8) {
            strip
            HStack(spacing: Self.gap) {
                Rectangle()
                    .fill(SettingsTheme.hairlineSubtle)
                    .frame(width: 1, height: 16)
                    .padding(.trailing, 2)
                    .accessibilityHidden(true)
                addButton
                editButton
            }
            .padding(.top, SettingsTheme.hoverTopRoom)
        }
        .modifier(LayerDeleteDialog(request: $deleteRequest, delete: delete))
    }

    // MARK: - The chips

    /// The chips in a line while they fit; past that a `SidewaysStrip`
    /// following the selected chip, its scroller under the chips only.
    private var strip: some View {
        let names = model.config.layers.map(\.name)
        return ViewThatFits(in: .horizontal) {
            chipLine(names)
                .padding(.top, SettingsTheme.hoverTopRoom)
                .frame(maxWidth: .infinity, alignment: .leading)
            SidewaysStrip(
                run: StripRun(
                    lengths: names.map { chipWidths[$0] ?? 0 },
                    gap: Self.gap,
                    depth: chipHeight
                ),
                followed: names.firstIndex(of: selected).map {
                    StripFollow(id: selected, index: $0)
                }
            ) {
                chipLine(names)
            }
        }
    }

    /// The fade's depth: a chip's drawn height, callout text and
    /// its vertical padding.
    private var chipHeight: CGFloat { 24 }

    private func chipLine(_ names: [String]) -> some View {
        HStack(spacing: Self.gap) {
            ForEach(names, id: \.self) { name in
                layerChip(name).id(name)
            }
        }
    }

    private func layerChip(_ name: String) -> some View {
        ShortcutLayerChip(
            name: name,
            selected: selected == name
        ) {
            selected = name
        }
        .focused($focusedChip, equals: name)
        .onGeometryChange(for: CGFloat.self) {
            $0.size.width
        } action: {
            chipWidths[name] = $0
        }
        .rowActions { chipMenu(name) }
    }

    @ViewBuilder
    private func chipMenu(_ name: String) -> some View {
        let fixed = name == KeyLayer.defaultName
        Button(L("shortcuts.layer_menu.edit", "Edit…")) {
            openEditor(name, focusingName: false)
        }
        .disabled(fixed)
        Button(L("shortcuts.rename_ellipsis", "Rename…")) {
            openEditor(name, focusingName: true)
        }
        .disabled(fixed || model.layerLockedHere(name))
        Button(L("shortcuts.layer_menu.delete", "Delete…")) {
            requestDelete(name)
        }
        .disabled(fixed || model.layerLockedHere(name))
    }

    // MARK: - + and ✎

    private var addButton: some View {
        glyphButton("plus", help: LayerEditorWords.addHelp) {
            editor = LayerEditorRequest(mode: .add, focusesName: true)
        }
        .popover(item: request(adding: true), arrowEdge: .bottom) { _ in
            LayerAddPopover(model: model) { added in
                editor = nil
                guard let added else { return }
                selected = added
            }
            .settingsPopoverChrome()
        }
    }

    /// ✎ edits the selected layer, greyed on `default`; the editor's
    /// rows anchor their search hits here, since a shut popover
    /// draws no anchor (#1250).
    private var editButton: some View {
        let fixed = selected == KeyLayer.defaultName
        return glyphButton(
            "pencil",
            help: fixed
                ? LayerEditorWords.defaultHelp
                : LayerEditorWords.editHelp(selected)
        ) {
            openEditor(selected, focusingName: false)
        }
        .disabled(fixed)
        .popover(item: request(adding: false), arrowEdge: .bottom) {
            request in
            LayerEditorPopover(
                model: model,
                layer: request.layer ?? selected,
                focusesName: request.focusesName,
                renamed: { selected = $0 },
                close: { editor = nil },
                delete: closeThenDelete
            )
            .settingsPopoverChrome()
        }
        .searchAnchored(SettingsCatalog.shortcuts.layersCard.children.reach)
        .searchAnchored(
            SettingsCatalog.shortcuts.layersCard.children.menuBarIcon
        )
    }

    private func glyphButton(
        _ symbol: String,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .choiceChip(edged: false)
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }

    /// The one request, seen by the anchor whose mode it carries.
    private func request(adding: Bool) -> Binding<LayerEditorRequest?> {
        Binding(
            get: { editor?.adds == adding ? editor : nil },
            set: { if $0 == nil, editor?.adds == adding { editor = nil } }
        )
    }

    private func openEditor(_ name: String, focusingName: Bool) {
        guard name != KeyLayer.defaultName else { return }
        selected = name
        editor = LayerEditorRequest(
            mode: .edit(name),
            focusesName: focusingName
        )
    }

    // MARK: - Delete

    /// Delete Layer… closes the popover first, so the dialog
    /// presents from the card on the next turn.
    private func closeThenDelete(_ name: String) {
        editor = nil
        DispatchQueue.main.async { requestDelete(name) }
    }

    private func requestDelete(_ name: String) {
        guard name != KeyLayer.defaultName else { return }
        guard model.layerDeleteAsks(name) else {
            delete(name, .everywhere)
            return
        }
        deleteRequest = LayerDeleteRequest(
            layer: name,
            count: model.layerDeleteCount(name),
            reading: model.layerReach(name)
        )
    }

    private func delete(_ removal: RuleRemoval) {
        guard let name = deleteRequest?.layer else { return }
        delete(name, removal)
    }

    /// Focus goes to the `default` chip, which the card always
    /// draws, and the selection with it when it was the one gone.
    private func delete(_ name: String, _ removal: RuleRemoval) {
        model.deleteLayer(name, removal)
        deleteRequest = nil
        if selected == name { selected = KeyLayer.defaultName }
        focusedChip = KeyLayer.defaultName
    }
}
