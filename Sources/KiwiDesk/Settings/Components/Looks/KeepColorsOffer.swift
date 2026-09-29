import KiwiDeskCore

/// The "Keep previous colors" row under the looks (#1752): the one
/// pure decision, so its rules are held by `KeepColorsOfferTests`
/// rather than by a view body. A look click brings the look's own
/// colours; the row offers back the ones it replaced, only where
/// no saved palette could.
struct KeepColorsOffer: Equatable {
    /// The colours the first look click of a run replaced.
    let previous: [String: String]
    /// The colours of the look clicked last.
    let look: [String: String]

    /// The offer after clicking `look` over `settings`, `prior`
    /// being the one standing: a run of look clicks keeps the
    /// first snapshot, so browsing looks never makes a look's own
    /// colours the ones to keep. Nil where a saved palette
    /// reproduces the colours replaced — the palette shelf is the
    /// way back there — or where the look changes no colour.
    static func afterClicking(
        _ look: ShelfLook,
        over settings: TilingSettings,
        prior: KeepColorsOffer?,
        palettes: [ColorPalette]
    ) -> KeepColorsOffer? {
        let live = ColorPaletteKeys.extract(from: settings)
        let previous =
            prior.flatMap { $0.shows(live) ? $0.previous : nil } ?? live
        guard !same(previous, look.colors),
            ColorPalette.first(reproducing: previous, in: palettes) == nil
        else { return nil }
        return KeepColorsOffer(previous: previous, look: look.colors)
    }

    /// Whether the row still stands over the draft's colours `live`:
    /// they are one of the two it switches between. A palette click
    /// or a hand edit leaves both, and retires it.
    func shows(_ live: [String: String]) -> Bool {
        isTicked(live) || Self.same(live, look)
    }

    /// Ticked exactly while the draft wears the previous colours.
    func isTicked(_ live: [String: String]) -> Bool {
        Self.same(live, previous)
    }

    /// The offer once the draft goes clean: a Save or a Revert ends
    /// the visit it speaks for, unless the write that cleaned the
    /// draft was the row's own tick — told by the write, never by
    /// the colours, which a Revert returns to the snapshot as well.
    static func afterDraftCleaned(
        _ offer: KeepColorsOffer?,
        tickWrote: Bool
    ) -> KeepColorsOffer? {
        tickWrote ? offer : nil
    }

    /// Two complete colour maps giving the same colour everywhere.
    static func same(
        _ a: [String: String],
        _ b: [String: String]
    ) -> Bool {
        ColorPalette(name: "", colors: a).reproduces(b)
    }
}
