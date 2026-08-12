import SwiftUI

/// The colours a CARD-FAN schematic draws its windows with —
/// Monocle's fan and Floating's pile, the two modes that draw a
/// stack of whole windows rather than a tiling.
///
/// One statement of the fallback ladder (plate palette → theme →
/// family constant), because what would be duplicated is the
/// RULE rather than a value: a copy that drifts on one arm draws
/// brand green on the user's own desktop plate in one schematic
/// and the folded palette in the other, side by side in the same
/// strip. `SchematicFocusStrokeTests` needles both call sites.
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
