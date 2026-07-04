import KiwiDeskCore
import SwiftUI

/// The monocle bar's color set (05_GUI_Concept §2, Tab 3). Each
/// row edits a `#RRGGBB(AA)` string with a live swatch.
struct MonocleColorsEditor: View {
    @Binding var bar: MonocleBarParams

    var body: some View {
        SettingsSection("Bar colors") {
            HexColorField(label: "Text", hex: $bar.textColor)
            HexColorField(label: "Box", hex: $bar.boxColor)
            HexColorField(
                label: "Active text",
                hex: $bar.activeTextColor
            )
            HexColorField(
                label: "Active box",
                hex: $bar.activeBoxColor
            )
            HexColorField(
                label: "Highlight",
                hex: $bar.highlightColor
            )
            HexColorField(label: "Hover", hex: $bar.hoverColor)
            HexColorField(
                label: "Hover text",
                hex: $bar.hoverTextColor
            )
            HexColorField(
                label: "Background",
                hex: $bar.backgroundColor
            )
            HexColorField(
                label: "Group badge",
                hex: $bar.groupBadgeColor
            )
            HexColorField(
                label: "Badge text",
                hex: $bar.groupBadgeTextColor
            )
        }
    }
}
