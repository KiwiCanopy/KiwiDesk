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
        // Through `reservedKeys`, the ONE derivation of
        // "reserved" — the dashed ring this state draws and
        // the legend entry gated on `reservedUnbound` must
        // read one source, or the board↔legend disagreement
        // class returns through the amber pair (re-review
        // 2026-08-10).
        if reservedKeys(scope: scope).contains(code) {
            return .cantBind
        }
        return .free
    }

    /// Whether macOS already owns this key under any selected
    /// modifier combination. A convenience OVER `reservedKeys`,
    /// never a second read of `SystemShortcuts.map` — the
    /// original subscript-by-combo body was a parallel
    /// derivation of "reserved" fourteen lines from the one the
    /// board and legend share, which is the equivalent-by-luck
    /// class the census exists to close (architect re-review
    /// 2026-08-10). Keyed on the SELECTION, because a key macOS
    /// owns under ⌘ is perfectly free under ⌃⌥.
    static func isSystemReserved(
        _ code: UInt32,
        under selected: Set<ModifierLayer>
    ) -> Bool {
        selected.contains {
            reservedKeys(scope: .one($0)).contains(code)
        }
    }

    /// The count sentence's number: how many distinct keys the
    /// scope claims.
    ///
    /// It derives from `claims`, so the sentence cannot disagree
    /// with the board above it. The modifier count went with the
    /// stripes: under `.all` it restated the chip row, and under
    /// `.one` it was always 1.
    static func takenKeyCount(
        claims: [UInt32: [ModifierLayer]]
    ) -> Int {
        claims.keys.count
    }

    /// Key codes where two bindings IN THE SAME LAYER claim the
    /// same combo — the red ring.
    ///
    /// Computed rather than read back out of
    /// `KebindingConflicts.conflicts(in:)`, because that returns
    /// display NAMES and rejoining them to key codes meant
    /// matching `Conflict.name` against `KeyBinding.label` — a
    /// binding with no label falls back to its combo string and
    /// was never ringed, and the match ran across every layer
    /// while conflicts are per layer.
    ///
    /// It also answers only the `.otherBinding` case on purpose:
    /// a clash with a macOS shortcut is `overwrittenReserved`'s
    /// — the same solid red since the owner ruled the overwrite
    /// conflict-class (2026-08-10), but a different question
    /// with a different gate.
    static func collisions(
        in layers: [KeyLayer],
        scope: Scope
    ) -> Set<UInt32> {
        var out: Set<UInt32> = []
        for layer in layers {
            var seen: Set<KeyCombo> = []
            for binding in layer.bindings {
                guard let combo = KeyCombo.parse(binding.combo)
                else { continue }
                let asLayer = ModifierLayer(
                    modifiers: combo.modifiers
                )
                switch scope {
                case .all: break
                case .one(let only):
                    guard asLayer == only else { continue }
                }
                if !seen.insert(combo).inserted {
                    out.insert(combo.keyCode)
                }
            }
        }
        return out
    }

    // MARK: - The conflict-class predicate (one owner)

    /// Every key macOS reserves under the shown modifier. Empty
    /// under `.all` on purpose — macOS reserves COMBINATIONS,
    /// not keys, so there is no single combination to check
    /// against there.
    static func reservedKeys(scope: Scope) -> Set<UInt32> {
        guard case .one(let layer) = scope else { return [] }
        return Set(
            SystemShortcuts.map.keys
                .filter {
                    ModifierLayer(modifiers: $0.modifiers)
                        == layer
                }
                .map(\.keyCode)
        )
    }

    /// The keys whose combo the user bound OVER a macOS
    /// reservation — conflict-class (owner ruled 2026-08-10:
    /// binding ⌘W does not un-own it), ringed the same solid
    /// red as an own-row collision. ONE predicate: the board's
    /// rings and the legend's gate both consume this, so the
    /// two cannot drift (architect review 2026-08-10 — they
    /// were composed independently at each site).
    static func overwrittenReserved(
        claims: [UInt32: [ModifierLayer]],
        scope: Scope
    ) -> Set<UInt32> {
        reservedKeys(scope: scope).filter {
            claims[$0]?.isEmpty == false
        }
    }

    /// The reserved keys still FREE under the shown modifier —
    /// the dashed amber ring's presence, and therefore its
    /// legend entry's gate: under a chip whose reservations are
    /// all bound, or a layer macOS reserves nothing under, the
    /// amber entry would point at a mark the board does not
    /// draw. ⌃⌥ was named here as such a layer; since #1094 it
    /// carries one reservation (⌃⌥space), so it is no longer an
    /// example of the empty case.
    static func reservedUnbound(
        claims: [UInt32: [ModifierLayer]],
        scope: Scope
    ) -> Set<UInt32> {
        reservedKeys(scope: scope).filter {
            claims[$0]?.isEmpty != false
        }
    }
}
