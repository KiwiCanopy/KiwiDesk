import KiwiDeskCore
import SwiftUI

/// Colors & glass swatches for borders and drag visuals.
extension ColorsAndGlassRow {
    @ViewBuilder func structureRow(_ key: BordersKey) -> some View {
        switch key {
        case .borderFocusedColor:
            HexColorField(
                label: L("border.title", "Focus border"),
                a11yLabel: L(
                    "border.focused_color.a11y",
                    "Focused window border color"
                ),
                hex: settings.borderStyle.focusedColor
            )
        case .borderUnfocusedColor:
            HexColorField(
                label: L(
                    "border.color.unfocused",
                    "Unfocused windows"
                ),
                a11yLabel: L(
                    "border.unfocused_color.a11y",
                    "Unfocused window border color"
                ),
                hex: settings.borderStyle.unfocusedColor
            )
        case .stickyColor:
            HexColorField(
                label: L("sticky.color", "Sticky"),
                a11yLabel: L(
                    "sticky.color.a11y",
                    "Sticky window mark color"
                ),
                automatic: true,
                hex: settings.stickyStyle.color
            )
        case .floatingColor:
            HexColorField(
                label: L("floating.color", "Floating"),
                a11yLabel: L(
                    "floating.color.a11y",
                    "Floating window mark color"
                ),
                automatic: true,
                hex: settings.floatingStyle.color
            )
        case .pocketColor:
            HexColorField(
                label: L("pocket.color", "Pocket"),
                a11yLabel: L(
                    "pocket.color.a11y",
                    "Pocket mark color"
                ),
                automatic: true,
                hex: settings.pocketStyle.color
            )
        default:
            let _ = assertionFailure(
                "non-colour Borders key in Colors & glass: "
                    + key.rawValue
            )
            EmptyView()
        }
    }
}
