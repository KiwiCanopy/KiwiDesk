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

    /// Master corner style binding
    /// (`GapsBordersGates.agreedCornerStyle`, #754).
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
