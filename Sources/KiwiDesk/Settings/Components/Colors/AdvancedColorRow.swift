import KiwiDeskCore
import SwiftUI

/// One swatch on the Advanced Colours page, chosen by census key
/// (#678 Phase 3). The four groups share this dispatcher so a row
/// moved between them in the census needs no renderer change
/// beyond its order list.
///
/// Each row carries its own gate here rather than at the call
/// site, because the predicate is per-key; the group's CONTAINER
/// gate is applied by the card, in parallel, never nested inside
/// this one.
struct AdvancedColorRow: View {
    @ObservedObject var model: SettingsModel
    let key: SettingKey
    /// False while the group's container gate is active. Every
    /// row predicate stands down then, so the hover names the
    /// outer reason instead of a row-specific one that fixing
    /// wouldn't un-grey anything (the Bars pattern).
    var containerAllows = true

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
            // The render-parity guard forces every
            // `.advancedColours` census row into an order list,
            // so an unhandled key here means a cross-family row
            // was placed in this area without a renderer arm.
            // Fail-open in release, loud in debug — never a
            // silently missing swatch.
            let _ = assertionFailure(
                "unrendered Advanced Colours key: \(key.id)"
            )
            EmptyView()
        }
    }

    /// The row-level grey: only ever active while the container
    /// gate allows editing, so the two cannot both claim the
    /// explanation.
    func gated(
        _ inert: Bool,
        _ help: String
    ) -> GreyOut {
        GreyOut(active: containerAllows && inert, help: help)
    }
}
