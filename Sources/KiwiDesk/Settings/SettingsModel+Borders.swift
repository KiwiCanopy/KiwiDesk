import KiwiDeskCore
import SwiftUI

/// Master bindings for shared border decisions across focus and drag visuals
/// (`SettingKey.masterWrites`, `BorderMastersFanOutTests`, #754).
extension SettingsModel {
    /// Master width binding updating borderStyle, dragGhost, and dragDropZone.
    var borderWidthMaster: Binding<CGFloat> {
        Binding(
            get: { self.config.settings.borderStyle.width },
            set: { value in
                var next = self.config.settings
                next.borderStyle.width = value
                next.dragGhost.borderWidth = value
                next.dragDropZone.borderWidth = value
                self.config.settings = next
            }
        )
    }

    /// Master corner style binding — OPTIONAL, nil while the two
    /// stored halves disagree (`GapsBordersGates.agreedCornerStyle`
    /// resolves it; `SegmentedPicker` renders no selection, #754).
    /// The getter never stores, and a pick is idempotent:
    /// re-affirming a segment must change nothing, or "opening
    /// this page rewrites nothing" lasts only until a stray tap —
    /// Rounded writes the system radius only where there is no
    /// rounding to keep; Square writes 0 outright.
    var borderCornersMaster: Binding<BorderStyle.CornerStyle?> {
        Binding(
            get: {
                GapsBordersGates(
                    settings: self.config.settings
                ).agreedCornerStyle
            },
            set: { style in
                guard let style else { return }
                var next = self.config.settings
                next.borderStyle.cornerStyle = style
                if style == .square {
                    next.dragCornerRadius = 0
                } else if next.dragCornerRadius <= 0 {
                    next.dragCornerRadius =
                        GeometryUtils.systemWindowCornerRadius
                }
                self.config.settings = next
            }
        )
    }
}
