import KiwiDeskCore

/// What the Shortcuts preview reports: which physical keys the
/// draft's bindings claim, under which modifier combinations.
///
/// Pure over `[KeyLayer]`, so the whole readout is assertable
/// without a view. The panel's three derived facts — the chip
/// row, the per-key stripes and the "N keys across M modifiers"
/// sentence — all come out of one fold here rather than being
/// recomputed beside the drawing.
enum KeyboardCensus {

    /// One modifier combination that at least one binding uses.
    ///
    /// The layer set is DERIVED, never a fixed four: the frame
    /// happens to show ⌥ / ⌥⇧ / ⌃⌥ / ⌘⌥ because that is what
    /// those bindings used. A config that binds nothing under ⌘
    /// offers no ⌘ chip.
    ///
    /// NOT a `KeyLayer`. A layer is a named alternate keymap and
    /// only one fires at a time; this is the modifier axis, and
    /// the two are independent — which is also why a key claimed
    /// by two different layers is not drawn as a conflict.
    struct ModifierLayer: Hashable, Comparable {
        let modifiers: HotkeyModifiers

        /// The modifier glyphs, EMPTY for a bare-key binding —
        /// which holds no modifier and so has no symbol. The
        /// word that names that case is the view's
        /// (`KeyboardKeyLabel.chipLabel`), because `L` is
        /// main-actor isolated and this type is deliberately not.
        var label: String {
            ComboSymbols.modifierSymbols(modifiers)
        }

        /// Ordered by how many modifiers are held, then by the
        /// Carbon mask, so the chips keep a stable reading order
        /// across renders and the simplest combination leads.
        static func < (a: Self, b: Self) -> Bool {
            let ca = a.modifiers.rawValue.nonzeroBitCount
            let cb = b.modifiers.rawValue.nonzeroBitCount
            if ca != cb { return ca < cb }
            return a.modifiers.rawValue < b.modifiers.rawValue
        }
    }

    /// How a drawn key reads at rest.
    ///
    /// `cantBind` is the STATIC `SystemShortcuts` table only. A
    /// live `RegisterEventHotKey` refusal is the app's other
    /// unbindable signal and is deliberately not here: it is
    /// per-attempt and cannot be enumerated, so promising it on
    /// a board drawn before any attempt would be a claim the
    /// panel cannot keep.
    enum KeyState: Equatable {
        case bound
        case free
        case cantBind
    }

    /// Every binding in the draft that has actually been
    /// recorded, parsed. `KeyBinding.combo` is an unparsed
    /// string and is EMPTY while a row is waiting for a chord,
    /// so an unrecorded row claims no key and must not count
    /// toward "taken".
    ///
    /// The emptiness is `KeyCombo.parse`'s to reject, not this
    /// function's — it guards on a non-empty key name and
    /// returns nil, so `compactMap` drops the row. A `filter`
    /// here would read as the thing keeping unrecorded rows out
    /// while actually being unreachable, which is worse than no
    /// filter: it survives any mutation, so a guard aimed at it
    /// can only pass.
    static func combos(in layers: [KeyLayer]) -> [KeyCombo] {
        layers
            .flatMap(\.bindings)
            .compactMap { KeyCombo.parse($0.combo) }
    }

    /// The modifier combinations the draft uses, in chip order.
    ///
    /// The bare-key combination is one of them. An earlier cut
    /// dropped it on the grounds that it would render as an
    /// empty chip — but the chip is named in words instead, and
    /// dropping it meant a binding on plain `L` or `return`
    /// appeared nowhere on a board whose question is what is
    /// taken (owner, 2026-08-10). It sorts first, holding the
    /// fewest modifiers.
    static func layers(in layers: [KeyLayer]) -> [ModifierLayer] {
        Set(
            combos(in: layers)
                .map { ModifierLayer(modifiers: $0.modifiers) }
        ).sorted()
    }

    /// Which selected modifier layers claim each key code — the
    /// stripe fold. A key with two entries is drawn with two
    /// stripes, which is how a two-layer collision stays legible
    /// on a single board.
    static func claims(
        in layers: [KeyLayer],
        selected: Set<ModifierLayer>
    ) -> [UInt32: [ModifierLayer]] {
        var out: [UInt32: Set<ModifierLayer>] = [:]
        for combo in combos(in: layers) {
            let layer = ModifierLayer(modifiers: combo.modifiers)
            guard selected.contains(layer) else { continue }
            out[combo.keyCode, default: []].insert(layer)
        }
        return out.mapValues { $0.sorted() }
    }

    /// What the board is showing: everything at once, or one
    /// modifier combination.
    ///
    /// Single-select, and the reason is that colour was never
    /// carrying its weight. Showing several combinations at once
    /// needed one hue each, hue is the channel colour-vision
    /// deficiency takes away, and only four hues cleared the
    /// separation floor against the key they sit on — so the
    /// board capped what it could show, and the cap is what made
    /// the panel's own headline answer false for anyone with
    /// five. One combination at a time needs no hue at all: the
    /// key's FILL says bound, free or can't-bind, and the
    /// question a user actually has at binding time — "if I hold
    /// ⌃⌥, what is left?" — is the drill-down rather than the
    /// overlay. Two combinations on one key never denoted a
    /// problem anyway; conflicts are per-layer and
    /// `KeybindingConflicts` reports them separately.
    enum Scope: Hashable {
        /// Every combination at once. A key is bound if anything
        /// claims it — the glance answer, and the only one that
        /// is true regardless of how many combinations exist.
        ///
        /// It deliberately reports no `cantBind`: macOS reserves
        /// a key UNDER a modifier, so "can't bind" has no meaning
        /// until one is chosen, and colouring keys black here
        /// would claim they are unavailable everywhere.
        case all
        case one(ModifierLayer)
    }

    /// The combinations in scope — all of them, or the one.
    static func inScope(
        _ scope: Scope,
        among layers: [ModifierLayer]
    ) -> Set<ModifierLayer> {
        switch scope {
        case .all: return Set(layers)
        case .one(let layer): return [layer]
        }
    }

    /// The state of one drawn key under the current selection.
    static func state(
        of code: UInt32,
        claims: [UInt32: [ModifierLayer]],
        scope: Scope
    ) -> KeyState {
        if claims[code]?.isEmpty == false { return .bound }
        if case .one(let layer) = scope,
            isSystemReserved(code, under: [layer])
        {
            return .cantBind
        }
        return .free
    }

    /// WHICH selected combinations macOS has reserved this key
    /// under — the frame's colours.
    ///
    /// The board draws two independent facts about one key:
    /// stripes say who has TAKEN it, the frame says who CANNOT
    /// have it. Answering "is it blocked" with a single Bool
    /// collapsed the second one, so a key macOS owns under ⌘ and
    /// leaves free under ⌃⌥ read as simply unavailable.
    static func blockers(
        of code: UInt32,
        under selected: Set<ModifierLayer>
    ) -> [ModifierLayer] {
        selected
            .filter {
                SystemShortcuts.map[
                    KeyCombo(keyCode: code, modifiers: $0.modifiers)
                ] != nil
            }
            .sorted()
    }

    /// Whether macOS already owns this key under any selected
    /// modifier combination.
    ///
    /// The predicate the repo never had: `SystemShortcuts.map`
    /// is public but only ever read as a raw subscript, inline
    /// in `KeybindingConflicts`. Keyed on the SELECTION, because
    /// a key macOS owns under ⌘ is perfectly free under ⌃⌥ —
    /// answering it selection-blind would grey half the board.
    static func isSystemReserved(
        _ code: UInt32,
        under selected: Set<ModifierLayer>
    ) -> Bool {
        selected.contains { layer in
            SystemShortcuts.map[
                KeyCombo(keyCode: code, modifiers: layer.modifiers)
            ] != nil
        }
    }

    /// The count sentence's number: how many distinct keys the
    /// scope claims.
    ///
    /// It derives from `claims`, so the sentence cannot disagree
    /// with the board above it. The modifier count went with the
    /// stripes: under `.all` it restated the chip row, and under
    /// `.one` it was always 1.
    static func tally(
        claims: [UInt32: [ModifierLayer]]
    ) -> (keys: Int, modifiers: Int) {
        let used = Set(claims.values.flatMap { $0 })
        return (claims.keys.count, used.count)
    }
}
