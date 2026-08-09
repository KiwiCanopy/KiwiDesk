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

    var fill: Color { accent.opacity(0.25) }
    var stroke: Color { accent.opacity(0.6) }
    var newFill: Color { accent.opacity(0.45) }
    var gapStroke: Color { ink.opacity(0.4) }
    var ghostFill: Color { ink.opacity(0.08) }
    var ghostStroke: Color { ink.opacity(0.3) }
    /// The mini-screen's own outline on the plate.
    var frame: Color { ink.opacity(0.3) }
}

private struct SchematicPaletteKey: EnvironmentKey {
    static let defaultValue: SchematicPalette? = nil
}

extension EnvironmentValues {
    /// `nil` — the default everywhere outside a desktop plate —
    /// keeps the family's brand constants.
    var schematicPalette: SchematicPalette? {
        get { self[SchematicPaletteKey.self] }
        set { self[SchematicPaletteKey.self] = newValue }
    }
}
