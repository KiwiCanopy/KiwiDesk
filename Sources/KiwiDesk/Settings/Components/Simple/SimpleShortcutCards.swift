import KiwiDeskCore
import SwiftUI

/// Simple's Open applications card (#2737 rulings 7, 16): the rows
/// the Shortcuts page draws, on the default layer, with the
/// recorder environment that page gives them — no Simple-only
/// recorder.
struct SimpleShortcutCards: View {
    @ObservedObject var model: SettingsModel
    /// Not in place: Simple cannot scroll to a row it does not
    /// draw, so a collision's way out is the row's card in Advanced.
    @StateObject private var coordinator: RecorderCoordinator

    init(model: SettingsModel) {
        self.model = model
        _coordinator = StateObject(
            wrappedValue: RecorderCoordinator { [model] anchor in
                model.openAdvanced(
                    SettingsAnchor(destination: .shortcuts, anchor: anchor)
                )
            }
        )
    }

    var body: some View {
        ApplicationsGroup(
            model: model,
            bindings: bindings,
            expander: expander,
            drawsKiwiDeskKeys: false,
            // Simple's card has no Shortcuts page around it to say
            // what it holds (owner 2026-10-29).
            caption: L(
                "simple.apps.caption",
                "Give the apps you use most a shortcut that opens "
                    + "or focuses them"
            ),
            drawsReach: false
        )
        .environment(
            \.recorderConflictAnchor,
            SettingsCatalog.shortcuts.openApplications.id
        )
        .environment(\.keybindingLayerName, layer)
        // One live read per render (#1105), as the Shortcuts page.
        .environment(
            \.disabledSystemShortcuts,
            model.disabledSystemShortcuts()
        )
        .recorderKeys(model)
        .environmentObject(coordinator)
        .onAppear {
            // Suspend hotkeys while capturing (#213).
            coordinator.onArmedChange = { [model] armed in
                model.setRecorderArmed(armed)
            }
        }
        .onChange(of: model.target) { _, _ in
            coordinator.invalidate()
        }
    }

    /// Simple edits the default layer alone.
    private var layer: String { KeyLayer.defaultName }

    private var layerIndex: Int? {
        model.config.layers.firstIndex { $0.name == layer }
    }

    private var bindings: Binding<[KeyBinding]> {
        Binding(
            get: {
                layerIndex.map { model.config.layers[$0].bindings }
                    ?? []
            },
            set: { rows in
                guard let index = layerIndex else { return }
                model.config.layers[index].bindings = rows
            }
        )
    }

    private var expander: ShortcutsFamilyRows {
        ShortcutsFamilyRows.ofDraft(model, layer: layer)
    }
}
