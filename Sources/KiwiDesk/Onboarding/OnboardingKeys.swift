import Foundation
import KiwiDeskCore

/// The chord families the tour teaches, read from the LIVE key
/// layer (#678 Phase 4 pass 11, turn 15a).
///
/// The move/follow PAIR ships together (owner, 2026-08-16): the
/// tour taught "move the window to a Space" while the seeded
/// keymap also binds move-and-follow on its own tier (`⌃⌥⇧`
/// against `⌃⌥⌘`), so a reader learned one of two chords that
/// differ by where they leave you — and the one they were not
/// shown is the one most people want most of the time.
///
/// **Every glyph here is looked up, never written.** Turn 15's own
/// mock-up closed by teaching `⌥1–5`, which is wrong twice over —
/// the seeded chord is `⌃⌥`, and bare Option is the macOS
/// special-character modifier, the very reason the scheme avoids
/// it. A literal in the copy is a promise the keymap does not
/// make, and a user who rebound anything would be taught someone
/// else's keyboard.
///
/// A family whose bindings are absent produces no row rather than
/// a row with an empty chord: the tour teaches what is bound.
@MainActor
enum OnboardingKeys {
    static func families(
        layer: KeyLayer,
        spaces: [SpaceID]
    ) -> [OnboardingKeyFamily] {
        var families: [OnboardingKeyFamily] = []
        if let focus = directional(
            layer: layer,
            command: "focus"
        ) {
            families.append(
                OnboardingKeyFamily(
                    id: "focus",
                    label: L(
                        "onboarding.keys.focus",
                        "Move focus"
                    ),
                    chord: focus,
                    tier: .movesFocus
                )
            )
        }
        if let swap = directional(layer: layer, command: "swap") {
            families.append(
                OnboardingKeyFamily(
                    id: "swap",
                    label: L(
                        "onboarding.keys.swap",
                        "Swap the window"
                    ),
                    chord: swap,
                    tier: .movesWindow
                )
            )
        }
        if let go = digits(
            layer: layer,
            command: "focus_space",
            spaces: spaces
        ) {
            families.append(
                OnboardingKeyFamily(
                    id: "focus_space",
                    label: L(
                        "onboarding.keys.go_to_space",
                        "Go to a Space"
                    ),
                    chord: go,
                    tier: .movesFocus
                )
            )
        }
        if let move = digits(
            layer: layer,
            command: "move_to_space",
            spaces: spaces
        ) {
            families.append(
                OnboardingKeyFamily(
                    id: "move_to_space",
                    label: L(
                        "onboarding.keys.move_to_space",
                        // Names the window. Each row is one
                        // accessibility element, so VoiceOver
                        // reads it alone and "it" referred to
                        // nothing — and every locale guessed
                        // differently, two producing labels
                        // indistinguishable from the row above
                        // (localization audit, 2026-08-11).
                        "Move the window to a Space"
                    ),
                    chord: move,
                    tier: .movesWindow
                )
            )
        }
        if let follow = digits(
            layer: layer,
            command: "move_to_space_and_follow",
            spaces: spaces
        ) {
            families.append(
                OnboardingKeyFamily(
                    id: "move_to_space_and_follow",
                    label: L(
                        "onboarding.keys.move_and_follow",
                        // The DIFFERENCE is carried by the two
                        // labels, not by a `?` beside them
                        // (owner asked, ruled 2026-08-16). The
                        // tour has no per-control help anywhere
                        // and adding the affordance for one row
                        // would put a new mechanism on the app's
                        // most minimal surface; "and follow it"
                        // against "to a Space" says the whole
                        // difference in the words, and says it to
                        // VoiceOver for free, which a popover
                        // does not.
                        //
                        // Worded off the Shortcuts page's own
                        // "& follow" rather than a synonym: one
                        // concept, one word per catalog
                        // (`docs/localization-naming.md`).
                        // Names the Space, like its sibling and
                        // for the sibling's reason: each tour
                        // row is ONE accessibility element read
                        // alone, and two locales had already
                        // produced labels indistinguishable
                        // from the row above when the
                        // destination was left implicit
                        // (localization audits 2026-08-11 and
                        // 2026-08-16). Dropping it here revived
                        // the milder form of that.
                        "Move the window to a Space and follow it"
                    ),
                    chord: follow
                )
            )
        }
        if let panel = single(
            combo: layer.bindings.first {
                $0.lua == ShortcutsOpenBinding.lua
            }?.combo
        ) {
            families.append(
                OnboardingKeyFamily(
                    id: "shortcuts",
                    label: L(
                        "onboarding.keys.all",
                        "See every shortcut"
                    ),
                    chord: panel,
                    isGateway: true
                )
            )
        }
        return families
    }

    /// The mental anchor: the tier RULE the rows are instances
    /// of (#1016).
    ///
    /// The seeded keymap is a tier system — `⌃⌥` moves the
    /// focus, `⌃⌥⇧` moves the window, `⌃⌥⌘` moves it and follows
    /// — but the step drew six unrelated rows, so a reader
    /// memorised five chords instead of learning one rule. The
    /// rule is the part that survives the tour.
    ///
    /// **DERIVED from the live chords, never asserted.** Every
    /// glyph in this step is looked up (`OnboardingKeys`), and a
    /// sentence claiming a tier is a claim about two modifier
    /// SETS — so a user who rebound swap off `⌃⌥⇧` is told
    /// nothing rather than told a lie. Suppressed, the step is
    /// exactly what it was before this lane, which is the safe
    /// side to fail to.
    ///
    /// The `⌘` tier is deliberately not named. It is a third
    /// clause for a chord the reader has not needed yet, and an
    /// anchor that lists everything is a sixth row rather than a
    /// rule.
    static func tierAnchor(
        _ rows: [OnboardingKeyFamily]
    ) -> String? {
        guard let base = sharedModifiers(rows, of: .movesFocus),
            let moves = sharedModifiers(rows, of: .movesWindow),
            // A bare-key tier 1 has no glyphs to name, and every
            // other clause waves it through: an empty set holds
            // no shift, and `[] ∪ ⇧ == [⇧]`. Unasked, the
            // sentence renders with no subject and a leading
            // space (`OnboardingTierAnchorTests`).
            !base.isEmpty,
            !base.contains(.shift),
            moves == base.union(.shift)
        else { return nil }
        return L(
            "onboarding.keys.tier",
            "%1$@ moves your focus. Add %2$@ to move the window.",
            ComboSymbols.modifierSymbols(base),
            ComboSymbols.modifierSymbols(.shift)
        )
    }

    /// The one modifier set every family of `tier` shares, or
    /// nil where none is bound or they disagree.
    ///
    /// A `mixed` family answers nil by construction: it HAS no
    /// shared set, which is the case the sentence must not speak
    /// over.
    private static func sharedModifiers(
        _ rows: [OnboardingKeyFamily],
        of tier: OnboardingKeyTier
    ) -> HotkeyModifiers? {
        let members = rows.filter { $0.tier == tier }
        let sets = members.compactMap { row -> HotkeyModifiers? in
            guard case .shared(let modifiers, _) = row.chord
            else { return nil }
            return modifiers
        }
        guard let first = sets.first,
            sets.count == members.count,
            sets.allSatisfy({ $0 == first })
        else { return nil }
        return first
    }
}
