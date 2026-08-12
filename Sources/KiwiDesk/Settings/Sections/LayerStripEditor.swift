import KiwiDeskCore
import SwiftUI

/// The Layers card's body: the chip strip that defines the
/// layers, the "+" popover that adds one, and the selected
/// layer's menu-bar icon with Rename / Delete.
///
/// Its own `View` rather than a computed property on
/// `ShortcutsHeader`: it owns four pieces of `@State`, and
/// `@State` on a struct that is never mounted in the hierarchy
/// silently does nothing. Splitting here also puts the header
/// back under the file-size target without widening any
/// `private` — the seam is real, not a line-count dodge.
///
/// At 268 lines this sits above the 100–250 target and below the
/// 350 ceiling, and it stays that way deliberately: the only
/// seam left (rename / add / delete) reads all four `@State`
/// properties, so extracting it means widening them to
/// `internal`. A soft size guideline does not buy a real seal,
/// and review reached the same conclusion for `ShortcutsHeader`
/// before this file existed.
struct LayerStripEditor: View {
    @ObservedObject var model: SettingsModel
    @Binding var selected: String
    @State private var addingLayer = false
    @State private var newLayer = ""
    @State private var renameRequest: NameEditRequest?
    @State private var addLayerHovered = false
    /// Where the keyboard lands after the selected layer's chip
    /// stops existing (#816).
    @FocusState private var focusedChip: String?
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            layerStrip
            Text(layersCaption)
                .font(.caption)
                .foregroundStyle(.secondary)
            selectedLayerHeader
        }
        .onChange(of: isEnabled) { _, now in
            if !now { addLayerHovered = false }
        }
    }

    private var layersCaption: String {
        L(
            "shortcuts.layers.caption",
            "Layers are alternate shortcut sets — only the "
                + "active layer's shortcuts fire. Bind a "
                + "key below to switch between them. "
                + "\u{201C}default\u{201D} is the standard "
                + "layer and is always the active one after "
                + "the app starts."
        )
    }

    // MARK: - Layer strip

    private var layerStrip: some View {
        HStack(spacing: 6) {
            ForEach(model.config.layers) { layer in
                layerChip(layer.name)
            }
            addLayerChip
        }
    }

    private func layerChip(_ name: String) -> some View {
        ShortcutLayerChip(
            name: name,
            selected: selected == name
        ) {
            selected = name
        }
        // Every chip is a focus destination, so a deletion can
        // name one (#816).
        .focused($focusedChip, equals: name)
    }

    /// Defining a layer is rare — the "+" chip's popover
    /// replaces the old always-visible text field (§3.6.1).
    private var addLayerChip: some View {
        Button {
            addingLayer = true
        } label: {
            Image(systemName: "plus")
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    Capsule().fill(
                        Color.secondary.opacity(
                            isEnabled && addLayerHovered
                                ? 0.18 : 0.12
                        )
                    )
                )
                .animation(hoverAnimation, value: addLayerHovered)
        }
        .buttonStyle(.plain)
        .onHover { addLayerHovered = isEnabled && $0 }
        .help(L("shortcuts.add_layer.help", "Add a layer"))
        .popover(isPresented: $addingLayer) {
            HStack {
                TextField(layerNamePlaceholder, text: $newLayer)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 140)
                    .onSubmit(addLayer)
                Button(L("shortcuts.add", "Add"), action: addLayer)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canAddLayer)
            }
            .padding(10)
        }
    }

    private var layerNamePlaceholder: String {
        L("shortcuts.layer_name", "Layer name")
    }

    private var hoverAnimation: Animation? {
        reduceMotion ? nil : .easeOut(duration: 0.12)
    }

    // MARK: - Selected-layer row

    /// A selected non-default layer gets a compact header: its
    /// menu-bar icon and Delete (base layers protected, #55).
    @ViewBuilder private var selectedLayerHeader: some View {
        if selected != KeyLayer.defaultName {
            HStack(spacing: 10) {
                Text(L("shortcuts.menu_bar_icon", "Menu bar icon"))
                    .foregroundStyle(.secondary)
                IconPicker(icon: iconBinding, preview: .menuBar)
                Spacer()
                if canDeleteSelected {
                    renameLayerButton
                    Button(
                        L("shortcuts.delete_layer", "Delete layer"),
                        role: .destructive,
                        action: deleteLayer
                    )
                    .buttonStyle(.bordered)
                } else {
                    // O4 soft: a base layer the profile
                    // doesn't mention always survives —
                    // removal is not expressible per profile
                    // (#55 phase 7).
                    Text(
                        L(
                            "shortcuts.base_layer_protected",
                            "Base layers can't be removed here"
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .font(.callout)
        }
    }

    private var layerIndex: Int {
        model.config.layers.firstIndex {
            $0.name == selected
        } ?? 0
    }

    private var iconBinding: Binding<String> {
        Binding(
            get: {
                model.config.layers[layerIndex].icon ?? ""
            },
            set: {
                model.config.layers[layerIndex].icon =
                    $0.isEmpty ? nil : $0
            }
        )
    }

    /// Rename shares Delete's gate (base layers are protected
    /// in profile-override editing, #55). Scope: the rewrite
    /// covers THIS config's layers and switch-layer rows; a
    /// stored profile whose sparse override (`Profile.layers`)
    /// targets the old name keeps it and resurfaces it as a
    /// standalone layer — the same accepted gap Delete has
    /// (pre-release, single user; the edit here is a draft
    /// until Save, so chasing stored files at click time
    /// would desync them from an unsaved base).
    private var renameLayerButton: some View {
        Button(L("shortcuts.rename_ellipsis", "Rename…")) {
            renameRequest = NameEditRequest(
                seed: selected,
                subject: selected
            )
        }
        .settingsActionButton()
        // By ITEM, so the seed reaches the builder rather than
        // being read back out of `@State` written one tick
        // earlier (#843) — the shape that left the palette
        // shelf's Save dead over a valid name.
        .popover(item: $renameRequest) { request in
            NameEditPopover(
                seed: request.seed,
                width: 140,
                confirmLabel: { _ in
                    L("shortcuts.rename", "Rename")
                },
                isValid: { canRenameLayer($0) }
            ) { draft in
                renameLayer(draft)
            }
        }
    }

    private func canRenameLayer(_ typed: String) -> Bool {
        let name = typed.trimmed
        return !name.isEmpty && name != selected
            && !model.config.layers.contains {
                $0.name == name
            }
    }

    private func renameLayer(_ typed: String) {
        guard canRenameLayer(typed) else { return }
        let new = typed.trimmed
        model.config.layers = KeybindingCatalog.renameLayer(
            in: model.config.layers,
            from: selected,
            to: new
        )
        selected = new
        renameRequest = nil
    }

    // MARK: - Layer mutations

    /// Live editing: any non-default layer. Override layer:
    /// only layers the PROFILE added — base layers always pass
    /// through (O4 soft), so deleting one is inexpressible.
    private var canDeleteSelected: Bool {
        guard selected != KeyLayer.defaultName else {
            return false
        }
        guard let base = model.profileEditingBaseLayers else {
            return true
        }
        return !base.contains { $0.name == selected }
    }

    private var canAddLayer: Bool {
        let name = newLayer.trimmed
        return !name.isEmpty
            && !model.config.layers.contains {
                $0.name == name
            }
    }

    private func addLayer() {
        let name = newLayer.trimmed
        guard canAddLayer else { return }
        // Seed the ⌃⌥K "Show shortcuts panel" row so a fresh layer
        // can open the cheat-sheet from the keyboard, not only via
        // the menu bar (#602). Deletable per layer like any default.
        model.config.layers.append(
            KeyLayer(
                name: name,
                bindings: [DefaultKeybindings.showShortcutsRow()]
            )
        )
        selected = name
        newLayer = ""
        addingLayer = false
    }

    /// Focus FOLLOWS the selection rather than stepping to the
    /// neighbouring chip (#816). The strip is a selector, not a
    /// list of independent rows: deleting the selected layer
    /// already moves the selection to the default layer, and
    /// every row below the strip is that layer's now, so landing
    /// anywhere else would leave the keyboard on a chip that
    /// does not match what is on screen.
    ///
    /// But only WHERE THE STRIP SURVIVES. `LayersCard` withholds
    /// itself entirely on `layersExist || mode == .powerUser`,
    /// and `layersExist` is "more than the default layer" — so in
    /// Simple mode, deleting the last custom layer retires the
    /// whole card in the same mutation, the default chip
    /// included. Naming it then sends focus to a view that left
    /// the tree, which lands at the top of the window: the exact
    /// outcome this rule exists to prevent, reached by the road
    /// gui.md warns about (code review, 2026-08-12). Nil is the
    /// honest answer there — the card the user was in is gone.
    private func deleteLayer() {
        guard selected != KeyLayer.defaultName else { return }
        model.config.layers.removeAll {
            $0.name == selected
        }
        selected = KeyLayer.defaultName
        focusedChip =
            stripSurvivesDeletion
            ? KeyLayer.defaultName : nil
    }

    /// Whether the card still draws after the deletion — asked
    /// of the card's OWN offer, never re-derived here: a second
    /// copy of an offer predicate is the drift
    /// `HomeCardOrder.isOffered` exists to prevent one level up,
    /// and an inverted copy is how a Simple-mode user ends up
    /// with focus on a card that left the tree.
    private var stripSurvivesDeletion: Bool {
        LayersCard.isOffered(
            config: model.config,
            mode: model.settingsMode
        )
    }
}
