import KiwiDeskCore

/// Controls whether the float facet offers title-pattern matching
/// (#1022, the `SpaceOverrideOffer` shape). Matching windows by a
/// fragment of their title is power-user work — you have to know
/// your app's window titles and that the test is a *contains* —
/// and it sat one click from the two choices a newcomer wants.
///
/// The three properties a cheap implementation breaks, all live
/// here. One app with patterns unlocks the choice on EVERY row (a
/// list-wide predicate, never per-row `count > 0`) — a user who
/// matches titles is a user who matches titles. The unlock reaches
/// this list and nothing else. And the mode never changes what
/// runs: patterns already saved keep matching in Simple, which is
/// why the predicate consults saved state rather than the mode
/// alone — otherwise a Simple user with patterns could neither see
/// nor clear them. HIDDEN rather than greyed when withheld (owner
/// ruling 2026-08-04), since the mode adds surface rather than
/// expanding it.
enum AppRuleTitleOffer {
    /// Offered in Power User mode, or while any float rule
    /// anywhere in the list carries a title pattern.
    ///
    /// `floatRules` is the union of the rules the reader can see:
    /// the draft's, plus the override base's while a stored
    /// profile is edited — a Simple user must still reach a
    /// pattern the base carries.
    static func isOffered(
        mode: SettingsMode,
        floatRules: [String]
    ) -> Bool {
        if mode == .powerUser { return true }
        return floatRules.contains { $0.contains(":") }
    }
}
