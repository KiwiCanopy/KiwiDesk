import KiwiDeskCore
import SwiftUI

/// Swatch dispatcher for the Colors & glass section (#678,
/// #2389), each row landing a search on its own catalog child.
struct AdvancedColorRow: View {
    @ObservedObject var model: SettingsModel
    let key: SettingKey

    var settings: Binding<TilingSettings> {
        $model.config.settings
    }

    var body: some View {
        if let anchor = ColorsAndGlassAnchors.control(for: key) {
            swatch.searchAnchored(anchor)
        } else {
            swatch
        }
    }

    @ViewBuilder private var swatch: some View {
        switch key {
        case .kiwishelf(let k):
            kiwishelfRow(k)
        case .spaceBar(let k):
            spaceBarRow(k)
        case .borders(let k):
            structureRow(k)
        default:
            let _ = assertionFailure(
                "unrendered colour key: \(key.id)"
            )
            EmptyView()
        }
    }
}
