import KiwiDeskCore
import SwiftUI

/// This Profile ▸ Appearance (#68 §3.2): how KiwiDesk looks
/// while you use it — gaps and the drag visuals. The App Bar
/// moved to its own sidebar destination (#229), so this stays a
/// short scroll of the controls people actually revisit.
struct AppearanceSection: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PaletteShelf(model: model)
                GapsEditor(model: model)
                DragVisualsEditor(model: model)
                FocusBorderEditor(model: model)
            }
            .padding(16)
        }
    }
}
