import CoreGraphics

/// Display-capacity stand-ins for schematic previews (#708). **A
/// schematic's ceiling is the engine's rule, never the canvas's**
/// (#712): clamp the drawing if you must, never the rule — a
/// clamped ceiling once made one config draw two capacities.
/// Every constant here is the same at every `SchematicScale`;
/// `LayoutSchematicTrackFoldTests.foldIsScaleIndependent` holds
/// it for the two Track constants. Stated residue:
/// `gridAutoSizeCap` has no scale-independence guard of its own —
/// one is owed.
extension LayoutSchematic {
    /// Grid preview stand-in for display-computed `auto_size` ceiling (#712).
    static let gridAutoSizeCap = (columns: 3, rows: 3)

    /// Track preview stand-in for `spillCapacity` (#437, #708).
    /// Three — the smallest number that SHOWS fill-then-spill: at
    /// two, every second window opens a track and the fill half
    /// never reads as filling.
    static let trackSpillCapacity = 3

    /// Track preview geometric cap — under `auto_tracks` ONLY: a
    /// stand-in fills in where the user gave no number, and
    /// passed unconditionally it overruled a typed limit of 6
    /// (architect review, 2026-08-16); `TrackSchematic+Fold`
    /// passes `.max` for a fixed limit. Without it the auto arm
    /// would never fold at all.
    static let trackGeoCap = 5
}
