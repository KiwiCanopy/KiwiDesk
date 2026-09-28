import KiwiDeskCore
import SwiftUI

/// The KiwiShelf Position master (#1731, `SettingKey.masterWrites`):
/// both bars' edges from one row.
extension SettingsModel {
    /// Master Position binding (#1731) — OPTIONAL, nil while the
    /// bars sit on different edges (`TilingSettings.sharedBarEdge`
    /// resolves it; `SegmentedPicker` renders no selection). A pick
    /// sets both bars' edges in one write, re-fusing them; the
    /// getter never stores.
    var barEdgeMaster: Binding<AppBarEdge?> {
        Binding(
            get: { self.config.settings.sharedBarEdge },
            set: { edge in
                guard let edge else { return }
                var next = self.config.settings
                next.spaceBarStyle.edge = edge
                next.appBarStyle.edge = edge
                guard next != self.config.settings else { return }
                self.config.settings = next
            }
        )
    }
}
