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
    /// Each chip's drawn size, which the strip's run reads.
    @State private var chipSizes: [String: CGSize] = [:]
    /// Keyboard focus target following layer deletion (#816).
    @FocusState private var focusedChip: String?

    private static let gap: CGFloat = 6
    /// Room past the end chips for a focus ring, inside the clip.
    private static let ringRoom: CGFloat = 4

    var body: some View {
        let names = model.config.layers.map(\.name)
        // ✎ and + follow the last chip while the chips fit, and pin
        // to the trailing edge once they scroll (#3263 amendment).
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 8) {
                chipLine(names).padding(.top, SettingsTheme.hoverTopRoom)
                controls
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            HStack(alignment: .top, spacing: 8) {
                strip(names)
                controls
            }
        }
        .modifier(LayerDeleteDialog(request: $deleteRequest, delete: delete))
    }

    /// The hairline, ✎ and +, given the strip's top room so they sit
    /// level with the chips in both shapes.
    private var controls: some View {
        HStack(spacing: Self.gap) {
            Rectangle()
                .fill(SettingsTheme.hairlineSubtle)
                .frame(width: 1, height: 16)
                .padding(.trailing, 2)
                .accessibilityHidden(true)
            editButton
            addButton
        }
        // The icon row's search anchor; ✎ holds Applies to's, so
        // each `.id` sits on its own view (#1250).
        .searchAnchored(
            SettingsCatalog.shortcuts.layersCard.children.menuBarIcon
        )
        .padding(.top, SettingsTheme.hoverTopRoom)
    }

    // MARK: - The chips

    /// The chips past what fits: a `SidewaysStrip` following the
    /// focused chip, else the selected one, its scroller under the
    /// chips only. Its run reads the chips' measured sizes, since a
    /// name sets each chip's width.
    private func strip(_ names: [String]) -> some View {
        SidewaysStrip(
            run: StripRun(
                lengths: names.map { chipSizes[$0]?.width ?? 0 },
                gap: Self.gap,
                depth: chipSizes.values.map(\.height).max() ?? 0,
                endRoom: Self.ringRoom
            ),
            followed: followed(in: names)
        ) {
            chipLine(names)
        }
    }

    private func followed(in names: [String]) -> StripFollow<String>? {
        let item =
            focusedChip.flatMap { names.contains($0) ? $0 : nil }
            ?? selected
        return names.firstIndex(of: item).map {
            StripFollow(id: item, index: $0)
        }
    }

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
            icon: chipIcon(name),
            selected: selected == name
        ) {
            selected = name
        }
        .focused($focusedChip, equals: name)
        .onGeometryChange(for: CGSize.self) {
            $0.size
        } action: {
            chipSizes[name] = $0
        }
        .rowActions { chipMenu(name) }
    }

    /// The draft layer's icon, as its switch rows read it — never
    /// `default`'s (#3267 ▸ Ruling 3).
    private func chipIcon(_ name: String) -> ShortcutGlyph? {
        ShortcutGlyph(icon: KeyLayer.icons(of: model.config.layers)[name])
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
        glyphButton("plus", label: LayerEditorWords.addHelp) {
            editor = LayerEditorRequest(mode: .add, focusesName: false)
        }
        .popover(item: request(adding: true), arrowEdge: .bottom) { _ in
            LayerAddPopover(model: model) { added in
                editor = nil
                guard let added else { return }
                selected = added
                // A turn later, once the chip is drawn.
                DispatchQueue.main.async { focusedChip = added }
            }
            .settingsPopoverChrome()
        }
    }

    /// ✎ edits the selected layer, greyed on `default`. Its group
    /// carries the editor rows' search anchors, since a shut popover
    /// draws none (#1250).
    private var editButton: some View {
        let fixed = selected == KeyLayer.defaultName
        return glyphButton(
            "pencil",
            label: LayerEditorWords.editHelp(selected),
            help: fixed ? LayerEditorWords.defaultHelp : nil
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
    }

    /// A glyph chip named by `label`; `help`, where given, is the
    /// reason a greyed one carries in its hover and hint.
    private func glyphButton(
        _ symbol: String,
        label: String,
        help: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .choiceChip(edged: false)
        }
        .buttonStyle(.plain)
        .help(help ?? label)
        .accessibilityLabel(label)
        .accessibilityHint(help ?? "")
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
