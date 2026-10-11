import KiwiDeskCore
import SwiftUI

/// The KiwiShelf Position master (#1731, `SettingKey.masterWrites`):
/// both bars' edges from one row.
extension SettingsModel {
    /// Master Position binding (#1731) — OPTIONAL, nil while the
    /// bars or their screens sit on different edges
    /// (`TilingSettings.uniformBarEdge`; `SegmentedPicker` renders
    /// no selection). A pick sets both bars on every screen in one
    /// write, re-fusing them and clearing each screen's own edge
    /// (#1948); the getter never stores.
    var barEdgeMaster: Binding<AppBarEdge?> {
        Binding(
            get: { self.config.settings.uniformBarEdge },
            set: { edge in
                guard let edge else { return }
                var next = self.config.settings
                next.spaceBarStyle.setEdge(edge)
                next.appBarStyle.setEdge(edge)
                guard next != self.config.settings else { return }
                self.config.settings = next
            }
        )
    }

    /// One bar's edge row — OPTIONAL, nil while its screens draw
    /// different edges (#1948); a pick sets that bar on every
    /// screen, clearing each screen's own edge.
    func barEdge<Bar: ScreenEdged>(
        _ bar: WritableKeyPath<TilingSettings, Bar>
    ) -> Binding<AppBarEdge?> {
        Binding(
            get: {
                let style = self.config.settings[keyPath: bar]
                return style.screensDiffer ? nil : style.edge
            },
            set: { edge in
                guard let edge else { return }
                var next = self.config.settings
                next[keyPath: bar].setEdge(edge)
                guard next != self.config.settings else { return }
                self.config.settings = next
            }
        )
    }
}
