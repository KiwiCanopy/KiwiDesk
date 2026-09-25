import KiwiDeskCore

/// The bar cards' slider bands where Core clamps one edge
/// (#1359, gui.md): that edge is DERIVED from the Core constant,
/// the other is the GUI's curation, Lua open beyond it.
/// `BarSliderBandTests` holds both the derivation and that every
/// consumer reads from here.
enum BarSliderBands {
    /// Both bars' Thickness rows: the Core floor up to 80 pt.
    static let thickness: ClosedRange<Double> =
        Double(KiwiShelf.minThickness)...80

    /// Both bars' margin rows (#1516): the Core floor up to a
    /// curated 60 pt — past the default outer gap by a wide
    /// margin, since the value is extra room.
    static let margin: ClosedRange<Double> =
        Double(KiwiShelf.minMargin)...60

    /// The Space Bar minimum row, in percent: both edges are
    /// Core's, which clamps the stored value to them (#1517).
    static let minimum: ClosedRange<Double> =
        Double(
            KiwiShelf.minimumRange.lowerBound
        )...Double(
            KiwiShelf.minimumRange.upperBound
        )

    /// The Space Bar's Spring delay row, in the seconds the row
    /// shows; `springDelayRange` is the milliseconds it stores.
    static let springDelaySeconds: ClosedRange<Double> = {
        let stored = SpaceBarStyle.springDelayRange
        let floor = Double(stored.lowerBound) / 1000
        let ceiling = Double(stored.upperBound) / 1000
        return floor...ceiling
    }()
}
