import SwiftUI

/// Card-fan schematic window colours (Monocle's fan, Floating's
/// pile). One statement of the fallback ladder (plate palette →
/// theme → family constant): what would be duplicated is the
/// RULE, and a copy drifting on one arm paints the two
/// schematics differently side by side.
/// `SchematicFocusStrokeTests` needles both call sites.
enum SchematicCardColors {
    static func fill(
        front: Bool,
        palette: SchematicPalette?
    ) -> Color {
        if front { return palette?.fill ?? LayoutSchematic.fill }
        return palette?.ghostFill
            ?? SettingsTheme.ink2.opacity(0.10)
    }

    /// The front card's edge is the FOCUS stroke where a mount
    /// wired one — the front card is that schematic's focus mark,
    /// and a strip must not show two focus colours disagreeing
    /// about what the colour means.
    static func edge(
        front: Bool,
        focusStroke: Color?,
        palette: SchematicPalette?
    ) -> Color {
        if front {
            return focusStroke ?? palette?.stroke
                ?? LayoutSchematic.stroke
        }
        return palette?.ghostStroke
            ?? SettingsTheme.ink2.opacity(0.4)
    }
}
