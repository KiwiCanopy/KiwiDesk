import KiwiDeskCore
import SwiftUI

/// +'s popover (#3263), the layer editor titled "New layer": its
/// name field focused, its icon unset, and Applies to shown where
/// `layerAdmission` places the layer, settable once it exists. Add
/// stays greyed until the decider takes the name; Cancel, Escape
/// and a close add nothing.
struct LayerAddPopover: View {
    @ObservedObject var model: SettingsModel
    /// Hands back the added layer's name, or nil for none.
    let done: (String?) -> Void
    @State private var name = ""
    @State private var icon = ""
    @FocusState private var nameFocused: Bool

    var body: some View {
        let typed = name.trimmed
        VStack(alignment: .leading, spacing: 10) {
            Text(LayerEditorWords.newLayer)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            LayerEditorGrid {
                LayerEditorForm.row(LayerEditorWords.name) {
                    nameField
                }
                LayerEditorForm.row(LayerEditorWords.icon) {
                    IconPicker(icon: $icon, preview: .menuBar)
                }
                if let reading = model.layerReach(typed),
                    LayerEditorWords.offersReach(reading)
                {
                    LayerEditorForm.row(LayerEditorWords.reach) {
                        reach(reading)
                    }
                }
            }
            Divider()
            HStack(spacing: 10) {
                Spacer()
                Button(LayerEditorWords.cancel) { done(nil) }
                    .keyboardShortcut(.cancelAction)
                Button(LayerEditorWords.add, action: add)
                    .buttonStyle(.borderedProminent)
                    .disabled(!model.canAddLayer(typed))
            }
        }
        .padding(12)
        .frame(width: LayerEditorForm.width, alignment: .leading)
        .onAppear {
            DispatchQueue.main.async { nameFocused = true }
        }
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField(LayerEditorWords.namePlaceholder, text: $name)
                .textFieldStyle(.roundedBorder)
                .focused($nameFocused)
                .onSubmit(add)
            if let caption = addCaption {
                LayerEditorForm.caption(caption.text, refused: caption.refused)
            }
        }
    }

    /// Where the layer will start, drawn dimmed with its reason: the
    /// checklist edits a layer the page has, and this one has none
    /// yet.
    private func reach(_ reading: RuleReachReading) -> some View {
        let start = LayerEditorWords.startingReach(reading)
        return VStack(alignment: .leading, spacing: 4) {
            Text(start)
                .foregroundStyle(SettingsTheme.ink3)
                .accessibilityLabel(LayerEditorWords.reach)
                .accessibilityValue(start)
            LayerEditorForm.caption(
                LayerEditorWords.reachAfterAdd,
                refused: false
            )
        }
    }

    /// What Add does with the typed name, read off the one
    /// decider; nil while it simply adds.
    private var addCaption: (text: String, refused: Bool)? {
        let typed = name.trimmed
        switch model.layerAdmission(typed) {
        case .clash(let holder)?:
            return (LayerReachWords.clash(holder, typed), true)
        case .sharedElsewhere?:
            return (LayerReachWords.joinOnLoadedPage, true)
        case .rejoin?:
            return (LayerReachWords.rejoins(typed), false)
        case .new?, nil:
            return nil
        }
    }

    private func add() {
        let typed = name.trimmed
        guard model.addLayer(typed) else { return }
        if !icon.isEmpty,
            let index = model.config.layers.firstIndex(where: {
                $0.name == typed
            })
        {
            model.config.layers[index].icon = icon
        }
        done(typed)
    }
}

/// The layer editor's label column and its captions, shared by the
/// add and edit popovers so the two draw one form.
struct LayerEditorGrid<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        Grid(
            alignment: .leadingFirstTextBaseline,
            horizontalSpacing: 10,
            verticalSpacing: 8
        ) {
            content()
        }
    }
}

/// The layer editor's form pieces, shared by both popovers.
@MainActor
enum LayerEditorForm {
    static let width: CGFloat = 340

    /// One labelled row. The label is drawn, not spoken: every
    /// control here names itself (#812).
    static func row(
        _ label: String,
        @ViewBuilder control: () -> some View
    ) -> some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
                .gridColumnAlignment(.trailing)
                .accessibilityHidden(true)
            control()
        }
    }

    static func caption(_ text: String, refused: Bool) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(
                refused ? SettingsTheme.danger : SettingsTheme.ink3
            )
            .fixedSize(horizontal: false, vertical: true)
    }
}
