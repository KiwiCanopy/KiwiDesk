import CoreGraphics

/// Display-capacity stand-ins for schematic previews on mini-canvases
/// (#708, #712; `LayoutSchematicTrackFoldTests.foldIsScaleIndependent`).
extension LayoutSchematic {
    /// Grid preview stand-in for display-computed `auto_size` ceiling (#712).
    static let gridAutoSizeCap = (columns: 3, rows: 3)

    /// Track preview stand-in for `spillCapacity` (#437, #708).
    static let trackSpillCapacity = 3

    /// Track preview geometric track cap under `auto_tracks` (architect
    /// review 2026-08-16).
    static let trackGeoCap = 5
}
