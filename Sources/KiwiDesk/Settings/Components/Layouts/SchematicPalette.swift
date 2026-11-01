import SwiftUI

/// Color source for schematic layouts (`SettingsTheme.accent`,
/// #712, #786). One ENVIRONMENT value carries the substitution —
/// an init parameter on the schematics would red
/// `LayoutSchematicCountTests` at every construction site. On the
/// plate, interiors are NEUTRAL (owner ruled 2026-08-09): the
/// accent lives on strokes and marks alone. On the light plate
/// (#2859) the plate owns every value but the focus ring.
struct SchematicPalette: Equatable {
    var accent: Color
    var ink: Color
    var base: Color
    var ground: PlateGround
    /// The look's focus colour, set where the light plate drew:
    /// its ring, or its active item colour while borders are off.
    var focus: Color? = nil

    private var light: Bool { ground == .light }

    var fill: Color {
        light ? SettingsTheme.lightWindow : ink.opacity(0.08)
    }
    var stroke: Color {
        light ? SettingsTheme.lightOutline : accent.opacity(0.6)
    }
    var newFill: Color {
        light ? SettingsTheme.lightWindow : ink.opacity(0.08)
    }
    var gapStroke: Color {
        light ? SettingsTheme.lightGap : ink.opacity(0.4)
    }
    var ghostFill: Color {
        light ? SettingsTheme.lightGhost : ink.opacity(0.08)
    }
    var ghostStroke: Color {
        light ? SettingsTheme.lightGhostEdge : ink.opacity(0.5)
    }
    var frame: Color {
        light ? SettingsTheme.lightFrame : ink.opacity(0.3)
    }
    /// A bars tile's screen well.
    var well: Color { light ? SettingsTheme.lightWell : ghostFill }
    /// The "+" of an incoming window.
    var mark: Color { light ? SettingsTheme.lightMark : ink }
    /// The plate's inset edge; `planeRing` stays the dark seam.
    var edge: Color {
        light ? SettingsTheme.lightEdge : SettingsTheme.planeRing
    }
    /// What marks the focused or active thing on the plate.
    var focusMark: Color { focus ?? accent }
    /// A gesture picture's window at rest.
    var windowFill: Color {
        light ? SettingsTheme.lightWindow : ink.opacity(0.10)
    }
    var windowEdge: Color {
        light ? SettingsTheme.lightOutline : ink.opacity(0.35)
    }
    /// Ink for plate chrome no look paints (the tour's menu bar).
    var chromeInk: Color { light ? ink : SettingsTheme.plateInk }
    /// A brand mark on the plate — a hover ring, the tour's icon
    /// ring — at 3:1 or more against it.
    var accentMark: Color {
        light ? SettingsTheme.lightAccent : SettingsTheme.accent
    }
    /// A bound key's edge against the board; none on the dark one.
    var boundKeyEdge: Color { light ? SettingsTheme.lightAccent : .clear }
}

/// Which plate a picture draws on (#2859): the dark plate, or the
/// light one a look earns in light mode.
enum PlateGround: Equatable {
    case dark
    case light
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
    /// (`LayoutSchematicView.focusStroke`, `border.focused_color`).
    var schematicFocusStroke: Color? {
        get { self[SchematicFocusStrokeKey.self] }
        set { self[SchematicFocusStrokeKey.self] = newValue }
    }
}
