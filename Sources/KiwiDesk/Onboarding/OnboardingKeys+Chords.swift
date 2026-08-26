import Foundation
import KiwiDeskCore

/// How `OnboardingKeys` turns a keymap's combos into the chord a
/// row draws — the fallback ladder, and nothing else.
///
/// Split out of `OnboardingKeys.swift` when #1016 pushed that
/// file past AGENTS.md §2.1's ceiling. These are `static` rather
/// than `private` only because Swift scopes `private` to the
/// FILE: they are the enum's internals, and a call site outside
/// this tree is a review finding rather than a supported route.
@MainActor
extension OnboardingKeys {
    /// Turn 15's reading order, which is also the arrow
    /// row's.
    private static let directions = [
        "left", "down", "up", "right",
    ]

    /// `⌃⌥ ← ↓ ↑ →` when all four directions share a modifier
    /// set; otherwise each chord in full, which is the honest
    /// rendering of a keymap that has been edited apart.
    static func directional(
        layer: KeyLayer,
        command: String
    ) -> OnboardingChord? {
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
    /// chords stacked in a 560 pt window.
    static func digits(
        layer: KeyLayer,
        command: String,
        spaces: [SpaceID]
    ) -> OnboardingChord? {
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
            let head = keyOnly(combo: first)
        else { return nil }
        let modifiers = parsed.modifiers
        guard combos.count > 1 else {
            return .shared(modifiers, keys: head)
        }
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
        else {
            return collapsed(combos) ?? listed(combos)
                ?? .shared(modifiers, keys: head)
        }
        return .shared(
            modifiers,
            keys: run.first + "–" + run.last
        )
    }

    /// The first and last key glyph, but only when every chord in
    /// between is a single digit stepping up by one.
    static func contiguousDigits(
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
    static func collapsed(
        _ combos: [String]
    ) -> OnboardingChord? {
        guard sameModifiers(combos),
            let first = combos.first,
            let parsed = KeyCombo.parse(first)
        else { return nil }
        let keys = combos.compactMap { keyOnly(combo: $0) }
        guard keys.count == combos.count else { return nil }
        return .shared(
            parsed.modifiers,
            keys: keys.joined(separator: " ")
        )
    }

    static func listed(
        _ combos: [String]
    ) -> OnboardingChord? {
        let each = combos.compactMap { rendered(combo: $0) }
        return each.isEmpty
            ? nil : .mixed(each.joined(separator: "  "))
    }

    static func sameModifiers(
        _ combos: [String]
    ) -> Bool {
        let sets = combos.compactMap { KeyCombo.parse($0)?.modifiers }
        guard sets.count == combos.count, let first = sets.first
        else { return false }
        return sets.allSatisfy { $0 == first }
    }

    /// A chord's key glyph alone — the full render minus the
    /// modifier symbols it starts with.
    static func keyOnly(combo: String) -> String? {
        guard let parsed = KeyCombo.parse(combo),
            let full = rendered(combo: combo)
        else { return nil }
        let modifiers = ComboSymbols.modifierSymbols(
            parsed.modifiers
        )
        guard full.hasPrefix(modifiers) else { return full }
        return String(full.dropFirst(modifiers.count))
    }

    /// One chord, split the way the multi-key families split
    /// theirs: the modifier set, then the key.
    ///
    /// The SPACE between them is `OnboardingChord.glyphs`' now,
    /// which is why this no longer writes one — `ComboSymbols
    /// .render` packs them tight (`⌃⌥K`), which is right in a
    /// recorder field and wrong in a list where every other row
    /// reads `⌃⌥ 1–5`, and the odd one out looked like a
    /// different kind of chord (owner, on device, 2026-08-12).
    /// Held there, that spacing is one rule rather than a
    /// courtesy each family remembers.
    static func single(
        combo: String?
    ) -> OnboardingChord? {
        guard let combo,
            let parsed = KeyCombo.parse(combo),
            let key = keyOnly(combo: combo)
        else {
            guard let full = rendered(combo: combo) else {
                return nil
            }
            return .mixed(full)
        }
        return .shared(parsed.modifiers, keys: key)
    }

    /// The same `ComboSymbols` + layout path the editor and the
    /// shortcuts panel use, so a chord is pixel-identical
    /// wherever the app draws it.
    static func rendered(combo: String?) -> String? {
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
