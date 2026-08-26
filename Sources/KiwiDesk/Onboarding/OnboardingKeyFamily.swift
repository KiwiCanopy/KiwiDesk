import Foundation
import KiwiDeskCore

/// One line of the tour's keys step: what it does, and the chord
/// that does it.
struct OnboardingKeyFamily: Identifiable, Equatable {
    let id: String
    /// Localized, spoken and drawn from this one string.
    let label: String
    /// The chord(s), kept STRUCTURED rather than as one glyph
    /// string (#1016).
    let chord: OnboardingChord
    /// Whether this row is the WAY OUT of the list: the chord
    /// that opens the shortcuts panel, where every other row is
    /// one thing the user can do.
    ///
    /// The tour draws it in the accent (#828, the prototype's
    /// filled chip) — it is the row that keeps mattering after
    /// the tour closes, and a list of six identical rows gives
    /// the reader nothing to take away. A FLAG rather than the
    /// view testing `id == "shortcuts"`: the id is a lookup key
    /// and a renamed one would silently un-mark the row.
    var isGateway = false
    /// Which half of the seeded tier scheme this family is, for
    /// the derived tier sentence — or nil where it is neither.
    ///
    /// A FIELD rather than the derivation matching on `id`, and
    /// for `isGateway`'s reason one line up: an id is a LOOKUP
    /// KEY, so a renamed one would drop the family out of the
    /// tier derivation silently — and invisibly to the tests,
    /// since every fixture goes through `families()` and a rename
    /// moves both sides of an id comparison at once. Declared
    /// beside the id it belongs to, the two cannot drift.
    var tier: OnboardingKeyTier?

    /// The chord as one native glyph string — what VoiceOver
    /// announces (`OnboardingView.keycap`'s
    /// `accessibilityLabel`), and the only rendering a `mixed`
    /// family has.
    ///
    /// DERIVED, never stored beside ``chord``: a second copy is a
    /// second thing to keep true, and the drawn caps and the
    /// spoken chord disagreeing is the one failure this step
    /// cannot afford (it exists to teach the chord). That is also
    /// why the spoken form comes from HERE rather than from the
    /// drawn chips — read as drawn, VoiceOver announced each `+`
    /// separator and each key name aloud, which is layout spoken
    /// as content.
    var glyphs: String { chord.glyphs }
}

/// Which half of the seeded scheme a family belongs to.
///
/// `⌃⌥` moves the focus, `⌃⌥⇧` moves the window, and `⌃⌥⌘`
/// moves it and follows. The tour states the first two as a RULE, so it
/// needs to know which families are instances of which — and the
/// third tier is deliberately unnamed here, an anchor that lists
/// everything being a sixth row rather than a rule.
enum OnboardingKeyTier {
    case movesFocus
    case movesWindow
}

/// A family's chord(s) with its modifier SET intact.
///
/// The tour is the one surface that has to name `⌃ ⌥ ⇧` in
/// words (#1016): they are exactly the three glyphs a first-time
/// Mac user cannot decode, and a German Apple keyboard prints
/// "ctrl" and "alt" on the caps rather than the symbols — so the
/// step has to draw each modifier as its own cap with a word
/// under it. A view cannot recover the SET from `⌃⌥ ← ↓ ↑ →`
/// without parsing glyphs back into modifiers, which would be a
/// second copy of `ComboSymbols`' table pointed the wrong way.
///
/// It is also what lets the tier sentence be DERIVED rather than
/// asserted: "add ⇧ to move the window" is a claim about two
/// modifier sets, and a keymap that has been rebound off the
/// seeded tiers must not be told it anyway.
enum OnboardingChord: Equatable {
    /// The modifiers every chord in the family shares, then the
    /// keys that differ — `⌃⌥` with `← ↓ ↑ →`, or with
    /// `1–5`.
    case shared(HotkeyModifiers, keys: String)
    /// A family edited apart, sharing no prefix: each chord
    /// written in full, and no modifier to name in words.
    case mixed(String)

    var glyphs: String {
        switch self {
        case .shared(let modifiers, let keys):
            let symbols = ComboSymbols.modifierSymbols(modifiers)
            guard !symbols.isEmpty else { return keys }
            guard !keys.isEmpty else { return symbols }
            // A space between the modifiers and the keys, the way
            // `single` already split the gateway row: packed
            // tight, a one-key family read as a different KIND of
            // chord from `⌃⌥ 1–5` beside it (owner, on device,
            // 2026-08-12). One rule now, so it cannot be true of
            // four rows and false of the fifth.
            return symbols + " " + keys
        case .mixed(let text):
            return text
        }
    }
}
