import KiwiDeskCore
import SwiftUI

/// Master bindings for shared border decisions across focus and drag visuals
/// (`SettingKey.masterWrites`, `BorderMastersFanOutTests`, #754); the
/// fan-out itself is Core's, which a look shares (#1739).
extension SettingsModel {
    /// Master width binding updating borderStyle, dragGhost, and dragDropZone.
    var borderWidthMaster: Binding<CGFloat> {
        Binding(
            get: { self.config.settings.borderStyle.width },
            set: { self.config.settings.setStrokeWidth($0) }
        )
    }

    /// Master corner style binding — OPTIONAL, nil while the two
    /// stored halves disagree (`GapsBordersGates.agreedCornerStyle`
    /// resolves it; `SegmentedPicker` renders no selection, #754).
    /// The getter never stores, and a pick is idempotent:
    /// re-affirming a segment must change nothing, or "opening
    /// this page rewrites nothing" lasts only until a stray tap
    /// (Core's `setStrokeCorners`).
    var borderCornersMaster: Binding<BorderStyle.CornerStyle?> {
        Binding(
            get: {
                GapsBordersGates(
                    settings: self.config.settings
                ).agreedCornerStyle
            },
            set: { style in
                guard let style else { return }
                self.config.settings.setStrokeCorners(style)
            }
        )
    }
}
