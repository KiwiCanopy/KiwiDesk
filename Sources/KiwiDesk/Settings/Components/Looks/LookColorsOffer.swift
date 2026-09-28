import KiwiDeskCore

/// What the colors row under the looks offers (#1684) — the one
/// pure decision, so option C's rules are held by
/// `LookColorsOfferTests` rather than by a view body.
enum LookColorsOffer: Equatable {
    /// The tick: checked while `palette` reads applied, unticking
    /// paints `before` back.
    case tick(palette: ColorPalette, before: ColorPalette)
    /// The look names a palette no longer saved.
    case paletteGone(String)

    /// The offer for `look`, clicked over colours `before`, now
    /// that the draft is `settings`; nil while there is nothing to
    /// say — the look superseded, its palette already live before
    /// the click, or the colours the user's own since.
    static func decide(
        look: ShelfLook,
        before: [String: String],
        palette: ColorPalette?,
        settings: TilingSettings
    ) -> Self? {
        guard look.isApplied(to: settings), let name = look.palette
        else { return nil }
        guard let palette else { return .paletteGone(name) }
        guard !palette.isApplied(matching: before) else { return nil }
        let prior = ColorPalette(name: "", colors: before)
        let live = ColorPaletteKeys.extract(from: settings)
        guard
            palette.isApplied(matching: live)
                || prior.isApplied(matching: live)
        else { return nil }
        return .tick(palette: palette, before: prior)
    }

    /// The colours a click on a look replaces: the ones the last
    /// clicked look replaced, while that look's palette is still
    /// what the draft shows — so a second click never makes the
    /// look's own colours the ones to restore — else the draft's.
    static func before(
        clicking previous: (look: ShelfLook, before: [String: String])?,
        previousPalette: ColorPalette?,
        settings: TilingSettings
    ) -> [String: String] {
        let live = ColorPaletteKeys.extract(from: settings)
        if let previous, let previousPalette,
            previousPalette.isApplied(matching: live)
        {
            return previous.before
        }
        return live
    }
}
