import KiwiDeskCore
import SwiftUI

/// +'s popover (#3263), the layer editor titled "New layer": its
/// name field focused, its icon unset, and Applies to shown where
/// `layerAdmission` places the layer, settable once it exists. A
/// rejoined shared layer shows its own icon, which it keeps. Add
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
            LayerEditorForm.grid {
                LayerEditorForm.row(LayerEditorWords.name) {
                    nameField
                }
                LayerEditorForm.row(LayerEditorWords.icon) {
                    iconPicker(typed)
                }
                if let reading = model.layerReach(typed),
                    LayerEditorForm.offersReach(reading)
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
                    .settingsActionButton()
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

    /// A rejoined shared layer's own icon, greyed: the rejoin
    /// caption under the name says why.
    @ViewBuilder
    private func iconPicker(_ typed: String) -> some View {
        if let shared = model.rejoinedLayerIcon(typed) {
            IconPicker(icon: .constant(shared), preview: .menuBar)
                .disabled(true)
        } else {
            IconPicker(icon: $icon, preview: .menuBar)
        }
    }

    /// Where the layer will start, drawn dimmed with its reason: the
    /// checklist edits a layer the page has, and this one has none
    /// yet.
    private func reach(_ reading: RuleReachReading) -> some View {
        let start = RuleReachWords.label(reading)
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
        case .new?:
            return nil
        case nil:
            return model.layerOnPageRefusal(typed).map { ($0, true) }
        }
    }

    private func add() {
        let typed = name.trimmed
        guard model.addLayer(typed, icon: icon) else { return }
        done(typed)
    }
}
