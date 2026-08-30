import KiwiDeskCore
import SwiftUI

/// Swatch dispatcher for the Advanced Colours page (#678).
struct AdvancedColorRow: View {
    @ObservedObject var model: SettingsModel
    let key: SettingKey
    /// Whether this row's own gate predicate is active
    /// (`AdvancedColorRows.gate`).
    var ownPredicateLive = true

    var settings: Binding<TilingSettings> {
        $model.config.settings
    }
    var gates: AdvancedColorsGates {
        AdvancedColorsGates(settings: model.config.settings)
    }

    @ViewBuilder var body: some View {
        switch key {
        case .appBar(let k):
            appBarRow(k)
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

    func gated(
        _ inert: Bool,
        _ help: String
    ) -> GreyOut {
        GreyOut(active: ownPredicateLive && inert, help: help)
    }
}
