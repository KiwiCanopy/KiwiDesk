import CoreGraphics

/// The stand-ins a schematic uses for a quantity the ENGINE
/// derives from a real display, which a mini-canvas is not.
///
/// One family, one file, because the alternative is what #708
/// nearly shipped: Grid already had a reasoned answer to this
/// class (`gridAutoSizeCap`, #712) and Track was about to get a
/// second, differently-argued one two files away. A schematic
/// meeting a display-derived ceiling takes a constant from here
/// and states it, rather than inventing a local number.
///
/// **A schematic's ceiling is the engine's rule, never the
/// canvas's** — the rule this family exists to keep. An earlier
/// cut of #712 clamped a ceiling to what the canvas could legibly
/// draw, which made the drawn *capacity* scale-dependent: rigid
/// 8 × 1 with five windows drew a two-window pile on the strip
/// thumbnail and none in the panel, inventing an overflow the
/// engine does not have. So every constant here is a stand-in for
/// a DISPLAY quantity and is the same at every
/// `SchematicScale` — clamp the drawing if you must; never the
/// rule. `LayoutSchematicStandInTests` holds that scale
/// independence, which is the property no reviewer can see by
/// reading one schematic.
extension LayoutSchematic {
    /// The Grid preview's stand-in for the one ceiling it cannot
    /// compute: `auto_size`, where `GridLayout.capDimensions`
    /// fits as many minimum-size cells as the *display* allows.
    /// The canvas is not a display and has no minimum window
    /// size, so it draws a plausible grid and the caption states
    /// these numbers rather than prose (#712).
    ///
    /// With auto-size **off** no stand-in is needed: the ceiling
    /// is the user's own typed columns × rows.
    static let gridAutoSizeCap = (columns: 3, rows: 3)

    /// The Track preview's stand-in for `spillCapacity` — how
    /// many windows fit in ONE track at `min_window_size`, which
    /// `TilingEngine.trackCapacities` measures against the real
    /// display (#437, #708).
    ///
    /// Three, because it is the smallest number that shows the
    /// rule rather than merely satisfying it: at two, every
    /// second window opens a track and the "fill" half of
    /// fill-then-spill never reads as filling.
    ///
    /// This is the RULE's number, not the drawing's. The focused
    /// track's drawn run is clamped separately, and the two must
    /// not be conflated — that conflation is exactly what #712's
    /// argument above forbids.
    static let trackSpillCapacity = 3

    /// The Track preview's stand-in for the geometric track cap —
    /// `geoCap` in `TrackLayout.overflowCap`, which on a real
    /// display is how many tracks fit across it.
    ///
    /// Five — four normal tracks beside one folded far-edge
    /// track. For a preview the canvas IS the display, so this is
    /// a genuine fit count rather than a clamp bolted onto a
    /// rule: five is what the strip shows without the tracks
    /// becoming slivers. It must not bind below the user's own
    /// `limit` at the shapes the limit control can reach, or the
    /// preview would answer a typed 4 with three tracks.
    ///
    /// Fixed across `SchematicScale`, which is the property that
    /// keeps this on the right side of #712: the thumbnail and
    /// the panel fold identically, so one configuration never
    /// draws two different capacities.
    ///
    /// Without a stand-in the preview would have to pass `.max`,
    /// and `auto_tracks` — where `normalCap` is `.max` too —
    /// would then never fold at all: an unbounded row of
    /// ever-thinner tracks and no overflow track, on the very
    /// setting whose whole story is that tracks open until the
    /// display runs out.
    static let trackGeoCap = 5
}
