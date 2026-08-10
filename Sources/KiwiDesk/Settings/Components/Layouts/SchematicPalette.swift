import SwiftUI

/// The colour source the schematic family draws with (#786).
///
/// At rest the family speaks brand — `SettingsTheme.accent` over
/// the Settings surfaces, via `LayoutSchematic.fill`/`.stroke`.
/// Inside a Home card's desktop plate the picture is of the
/// USER's desktop, so the user's palette owns the window colours
/// (4g) — and the ground there is dark in both appearances, so
/// the greys the canvas idiom leans on (`.secondary`,
/// `.textBackgroundColor`) would vanish in light mode and glare
/// in dark. One environment value carries the whole
/// substitution; an init parameter on the schematics would red
/// `LayoutSchematicCountTests` at every construction site.
struct SchematicPalette: Equatable {
    /// A window: the fill base and stroke — the user's own
    /// accent, read from the draft's palette surface.
    var accent: Color
    /// The quiet marks: empty cells, ghosts, the monitor
    /// outline — a light ink legible on the dark ground.
    var ink: Color
    /// The opaque base under piled tiles — the ground itself,
    /// so stacking never sums the accent alpha (#712's rule,
    /// with the plate as the base).
    var base: Color

    // Interiors are NEUTRAL on the plate — the quiet ink wash
    // every tile shares — never the accent: the owner compared
    // the tiles side by side and ruled the filled-green
    // windows out (2026-08-09); on the plate the accent lives
    // on strokes and marks alone.
    var fill: Color { ink.opacity(0.08) }
    var stroke: Color { accent.opacity(0.6) }
    // Identical to `fill` on the plate (owner, 2026-08-09):
    // even the denser ink wash read as "a different colour" on
    // the tile — the "+" badge alone marks the incoming
    // window; brand keeps its denser fill off-plate.
    var newFill: Color { ink.opacity(0.08) }
    var gapStroke: Color { ink.opacity(0.4) }
    var ghostFill: Color { ink.opacity(0.08) }
    var ghostStroke: Color { ink.opacity(0.3) }
    /// The mini-screen's own outline on the plate.
    var frame: Color { ink.opacity(0.3) }
}

private struct SchematicPaletteKey: EnvironmentKey {
    static let defaultValue: SchematicPalette? = nil
}

private struct SchematicFocusStrokeKey: EnvironmentKey {
    static let defaultValue: Color? = nil
}

extension EnvironmentValues {
    /// `nil` — the default everywhere outside a desktop plate —
    /// keeps the family's brand constants.
    var schematicPalette: SchematicPalette? {
        get { self[SchematicPaletteKey.self] }
        set { self[SchematicPaletteKey.self] = newValue }
    }

    /// The stroke an ACTIVE tile marks focus with: the draft's
    /// real `border.focused_color` (owner ruled 2026-08-10,
    /// extending the Gaps ring's honesty rule — a preview
    /// claiming engine behavior shows the colour the app will
    /// draw). `nil` — borders disabled, or a mount that has not
    /// wired it — keeps the family stroke, which claims
    /// nothing. On a plate the mount floors the colour against
    /// the plate first (`HomeCardPlate.plateLegible`).
    var schematicFocusStroke: Color? {
        get { self[SchematicFocusStrokeKey.self] }
        set { self[SchematicFocusStrokeKey.self] = newValue }
    }
}
