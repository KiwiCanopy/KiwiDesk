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
                // The bars take most of a palette's paint but
                // preview in their own tab — mirror them here
                // so a shelf click visibly changes something
                // (ui-designer 2026-07-19).
                PaletteBarMirror(model: model)
                GapsEditor(model: model)
                DragVisualsEditor(model: model)
                FocusBorderEditor(model: model)
                StickyMarkEditor(model: model)
            }
            .padding([.horizontal, .bottom], SettingsMetrics.paneInset)
        }
    }
}
