import Foundation
import KiwiDeskCore

/// One line of the tour's keys step: what it does, and the chord
/// that does it.
struct OnboardingKeyFamily: Identifiable, Equatable {
    let id: String
    /// Localized, spoken and drawn from this one string.
    let label: String
    /// Native glyphs — `⌃⌥ ← ↓ ↑ →`, `⌃⌥ 1–5`.
    let glyphs: String
}

/// The five chord families the tour teaches, read from the LIVE
/// key layer (#678 Phase 4 pass 11, turn 15a).
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
    /// Turn 15's reading order, which is also the arrow row's.
    private static let directions = ["left", "down", "up", "right"]

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
                    glyphs: focus
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
                    glyphs: swap
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
                    glyphs: go
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
                    glyphs: move
                )
            )
        }
        if let panel = rendered(
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
                    glyphs: panel
                )
            )
        }
        return families
    }

    /// `⌃⌥ ← ↓ ↑ →` when all four directions share a modifier
    /// set; otherwise each chord in full, which is the honest
    /// rendering of a keymap that has been edited apart.
    private static func directional(
        layer: KeyLayer,
        command: String
    ) -> String? {
        let combos = directions.compactMap { direction in
            layer.bindings.first {
                $0.lua == "KiwiDesk.\(command)(\"\(direction)\")"
                    && !$0.combo.isEmpty
            }?.combo
        }
        guard combos.count == directions.count else {
            return listed(combos)
        }
        return collapsed(combos) ?? listed(combos)
    }

    /// `⌃⌥ 1–5`: the shared modifiers, then the first and last
    /// bound digit. A single space renders as one digit, never a
    /// range of one.
    ///
    /// A keymap that cannot be written as a range falls back the
    /// way the arrows path already does — `collapsed` first, so
    /// ten spaces render `⌃⌥ 1 2 4 5 …` rather than ten full
    /// chords stacked in a 520 pt window.
    private static func digits(
        layer: KeyLayer,
        command: String,
        spaces: [SpaceID]
    ) -> String? {
        let combos = spaces.compactMap { space in
            layer.bindings.first {
                $0.lua
                    == "KiwiDesk.\(command)"
                    + "(\(SpaceLuaArg.quote(space.raw)))"
                    && !$0.combo.isEmpty
            }?.combo
        }
        guard let first = combos.first,
            let parsed = KeyCombo.parse(first),
            let head = rendered(combo: first)
        else { return nil }
        let modifiers = ComboSymbols.modifierSymbols(
            parsed.modifiers
        )
        guard combos.count > 1 else { return head }
        // A range may only be written where the digits ACTUALLY
        // run unbroken from the first to the last. `combos` is
        // compacted, so an unbound space in the middle vanishes
        // and "1–5" would name a chord the user does not have —
        // the same lie the arrows path refuses (code review,
        // 2026-08-11). It also catches the tenth space, which
        // `DefaultKeybindings` maps to `0`: "1–0" runs backwards
        // and is not a range at all.
        //
        // Contiguity is the WHOLE test. An earlier cut also
        // required a chord per live space, which suppressed a
        // range that was true — five spaces with only 1…3 bound
        // renders "⌃⌥ 1–3", an honest statement about the chords
        // the user has. Nothing watched that clause, and removing
        // it reds nothing, because it forbade nothing the
        // invariant forbids (guard-prover, 2026-08-11).
        guard sameModifiers(combos),
            let run = contiguousDigits(combos)
        else { return collapsed(combos) ?? listed(combos) ?? head }
        return modifiers + " " + run.first + "–" + run.last
    }

    /// The first and last key glyph, but only when every chord in
    /// between is a single digit stepping up by one.
    private static func contiguousDigits(
        _ combos: [String]
    ) -> (first: String, last: String)? {
        let keys = combos.compactMap { keyOnly(combo: $0) }
        guard keys.count == combos.count else { return nil }
        let values = keys.compactMap { key -> Int? in
            guard key.count == 1 else { return nil }
            return Int(key)
        }
        guard values.count == keys.count, let start = values.first
        else { return nil }
        for (offset, value) in values.enumerated()
        where value != start + offset {
            return nil
        }
        guard let firstKey = keys.first, let lastKey = keys.last
        else { return nil }
        return (firstKey, lastKey)
    }

    /// The shared modifiers once, then each chord's key glyph.
    private static func collapsed(_ combos: [String]) -> String? {
        guard sameModifiers(combos),
            let first = combos.first,
            let parsed = KeyCombo.parse(first)
        else { return nil }
        let keys = combos.compactMap { keyOnly(combo: $0) }
        guard keys.count == combos.count else { return nil }
        return ComboSymbols.modifierSymbols(parsed.modifiers)
            + " " + keys.joined(separator: " ")
    }

    private static func listed(_ combos: [String]) -> String? {
        let each = combos.compactMap { rendered(combo: $0) }
        return each.isEmpty ? nil : each.joined(separator: "  ")
    }

    private static func sameModifiers(
        _ combos: [String]
    ) -> Bool {
        let sets = combos.compactMap { KeyCombo.parse($0)?.modifiers }
        guard sets.count == combos.count, let first = sets.first
        else { return false }
        return sets.allSatisfy { $0 == first }
    }

    /// A chord's key glyph alone — the full render minus the
    /// modifier symbols it starts with.
    private static func keyOnly(combo: String) -> String? {
        guard let parsed = KeyCombo.parse(combo),
            let full = rendered(combo: combo)
        else { return nil }
        let modifiers = ComboSymbols.modifierSymbols(
            parsed.modifiers
        )
        guard full.hasPrefix(modifiers) else { return full }
        return String(full.dropFirst(modifiers.count))
    }

    /// The same `ComboSymbols` + layout path the editor and the
    /// shortcuts panel use, so a chord is pixel-identical
    /// wherever the app draws it.
    private static func rendered(combo: String?) -> String? {
        guard let combo, !combo.isEmpty else { return nil }
        guard let parsed = KeyCombo.parse(combo) else {
            return combo
        }
        return ComboSymbols.render(
            parsed,
            layoutChar: LayoutKeyGlyph.char
        )
    }
}
