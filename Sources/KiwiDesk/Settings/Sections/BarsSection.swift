import KiwiDeskCore
import SwiftUI

/// This Profile ▸ Bars, the first area rendered from the
/// settings census (#678 Phase 2, turn 7a): one page — the
/// Space Bar card and the App Bar card with its "Show it in"
/// switches. The #293 App Bar / Space Bar switch is gone: both
/// cards fit one scroll now that the per-layout override
/// sub-editors left the GUI (GUI_REMOVED_2026-08; per-layout
/// styling stays fully available in Lua).
///
/// Space Bar leads, matching everywhere else it does
/// (ui-designer 2026-07-19): it is omnipresent across every
/// layout, while the App Bar renders only where a layout shows
/// one.
///
/// No colours here. The interim colour cards retired in #678
/// Phase 3, when Advanced Colours started rendering every bar
/// tint from the same census rows — a colour that renders in two
/// areas has two answers to "what is this set to", and
/// `SettingsColorSurfaceTests` now pins that it renders in one.
struct BarsSection: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SpaceBarCard(model: model)
                AppBarCard(model: model)
            }
            .padding([.horizontal, .bottom], SettingsMetrics.paneInset)
        }
    }
}
