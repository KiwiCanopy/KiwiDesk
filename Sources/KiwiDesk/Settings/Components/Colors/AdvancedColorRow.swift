import KiwiDeskCore
import SwiftUI

/// Swatch dispatcher for the Advanced Colours page (#678).
struct AdvancedColorRow: View {
    @ObservedObject var model: SettingsModel
    let key: SettingKey

    var settings: Binding<TilingSettings> {
        $model.config.settings
    }

    @ViewBuilder var body: some View {
        switch key {
        case .kiwishelf(let k):
            kiwishelfRow(k)
        case .spaceBar(let k):
            spaceBarRow(k)
        case .borders(let k):
            structureRow(k)
        default:
            let _ = assertionFailure(
                "unrendered Advanced Colours key: \(key.id)"
            )
            EmptyView()
        }
    }
}
