import SwiftUI

/// Color source for schematic layouts (`SettingsTheme.accent`, #712, #786).
struct SchematicPalette: Equatable {
    var accent: Color
    var ink: Color
    var base: Color

    var fill: Color { ink.opacity(0.08) }
    var stroke: Color { accent.opacity(0.6) }
    var newFill: Color { ink.opacity(0.08) }
    var gapStroke: Color { ink.opacity(0.4) }
    var ghostFill: Color { ink.opacity(0.08) }
    var ghostStroke: Color { ink.opacity(0.5) }
    var frame: Color { ink.opacity(0.3) }
}

private struct SchematicPaletteKey: EnvironmentKey {
    static let defaultValue: SchematicPalette? = nil
}

private struct SchematicFocusStrokeKey: EnvironmentKey {
    static let defaultValue: Color? = nil
}

extension EnvironmentValues {
    /// Schematic palette override; nil uses standard brand colors.
    var schematicPalette: SchematicPalette? {
        get { self[SchematicPaletteKey.self] }
        set { self[SchematicPaletteKey.self] = newValue }
    }

    /// Focus stroke color for active schematic tile
    /// (`HomeCardPlate.plateLegible`, `border.focused_color`).
    var schematicFocusStroke: Color? {
        get { self[SchematicFocusStrokeKey.self] }
        set { self[SchematicFocusStrokeKey.self] = newValue }
    }
}
