import KiwiDeskCore

/// Shortcuts preview data derivations over `[KeyLayer]`.
enum KeyboardCensus {

    /// One modifier combination used by at least one binding.
    struct ModifierLayer: Hashable, Comparable {
        let modifiers: HotkeyModifiers

        /// Modifier glyphs, or empty for bare keys (`KeyboardKeyLabel`).
        var label: String {
            ComboSymbols.modifierSymbols(modifiers)
        }

        /// Ordered by modifier count then raw value for stable reading order.
        static func < (a: Self, b: Self) -> Bool {
            let ca = a.modifiers.rawValue.nonzeroBitCount
            let cb = b.modifiers.rawValue.nonzeroBitCount
            if ca != cb { return ca < cb }
            return a.modifiers.rawValue < b.modifiers.rawValue
        }
    }

    /// Drawn key state at rest.
    enum KeyState: Equatable {
        case bound
        case free
        case cantBind
    }

    /// The one keybinding layer the board draws (#1127;
    /// `docs/design-decisions.md` argues why one and not the
    /// union). A name no layer answers to falls back rather than
    /// drawing nothing — the strip's selection outlives a rename
    /// by a frame, and an empty board reads "everything is free".
    static func shown(
        _ name: String,
        in layers: [KeyLayer]
    ) -> [KeyLayer] {
        let match =
            layers.first { $0.name == name }
            ?? layers.first { $0.isDefault }
            ?? layers.first
        return match.map { [$0] } ?? []
    }

    /// Parses non-empty key bindings across layers (`KeyCombo.parse`).
    static func combos(in layers: [KeyLayer]) -> [KeyCombo] {
        layers
            .flatMap(\.bindings)
            .compactMap { KeyCombo.parse($0.combo) }
    }

    /// Modifier combinations in chip sort order.
    static func layers(in layers: [KeyLayer]) -> [ModifierLayer] {
        Set(
            combos(in: layers)
                .map { ModifierLayer(modifiers: $0.modifiers) }
        ).sorted()
    }

    /// Mapping of key codes to matching selected modifier layers.
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

    /// One key's bindings under the selected modifier layers
    /// (#798), in the chip strip's own order.
    ///
    /// Beside `claims` and over the same arguments on purpose: a
    /// second fold written in the view is how the strip comes to
    /// name an action on a key the fill says is free.
    static func bindings(
        on code: UInt32,
        in layers: [KeyLayer],
        selected: Set<ModifierLayer>
    ) -> [(layer: ModifierLayer, binding: KeyBinding)] {
        layers.flatMap(\.bindings).enumerated()
            .compactMap {
                offset,
                binding -> (
                    offset: Int, layer: ModifierLayer,
                    binding: KeyBinding
                )? in
                guard let combo = KeyCombo.parse(binding.combo),
                    combo.keyCode == code
                else { return nil }
                let layer = ModifierLayer(
                    modifiers: combo.modifiers
                )
                guard selected.contains(layer) else { return nil }
                return (offset, layer, binding)
            }
            .sorted {
                // By LAYER, so the reading matches the chip
                // strip; position only breaks a tie, since
                // `sorted(by:)` is not documented stable and a
                // COLLISION is two claims in one layer — the
                // case this exists for.
                $0.layer == $1.layer
                    ? $0.offset < $1.offset
                    : $0.layer < $1.layer
            }
            .map { (layer: $0.layer, binding: $0.binding) }
    }

    /// Filter scope for keyboard preview.
    enum Scope: Hashable {
        case all
        case one(ModifierLayer)
    }

    /// Active modifier combinations in given scope.
    static func inScope(
        _ scope: Scope,
        among layers: [ModifierLayer]
    ) -> Set<ModifierLayer> {
        switch scope {
        case .all: return Set(layers)
        case .one(let layer): return [layer]
        }
    }

    /// State of a drawn key under current scope (`reservedKeys`).
    static func state(
        of code: UInt32,
        claims: [UInt32: [ModifierLayer]],
        scope: Scope
    ) -> KeyState {
        if claims[code]?.isEmpty == false { return .bound }
        if reservedKeys(scope: scope).contains(code) {
            return .cantBind
        }
        return .free
    }

    /// Whether macOS owns key under any selected modifier combination.
    static func isSystemReserved(
        _ code: UInt32,
        under selected: Set<ModifierLayer>
    ) -> Bool {
        selected.contains {
            reservedKeys(scope: .one($0)).contains(code)
        }
    }

    /// Count of distinct taken keys in scope.
    static func takenKeyCount(
        claims: [UInt32: [ModifierLayer]]
    ) -> Int {
        claims.keys.count
    }

    /// Collisions where two bindings in the same layer share a combo.
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

    // MARK: - Conflict-class predicates

    /// System-reserved keys under shown modifier (#1094).
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

    /// Every key the board RINGS under the shown scope (#798):
    /// an own-layer collision, or a binding over a macOS
    /// reservation. One derivation, because the ring, the words
    /// under the pointer and the spoken conflict clause must
    /// name the same keys or the picture and its description
    /// disagree.
    static func ringedKeys(
        in layers: [KeyLayer],
        selected: Set<ModifierLayer>,
        scope: Scope
    ) -> Set<UInt32> {
        collisions(in: layers, scope: scope)
            .union(
                overwrittenReserved(
                    claims: claims(in: layers, selected: selected),
                    scope: scope
                )
            )
    }

    /// The chord the shown scope names, empty under `.all` —
    /// where there is no single combination to name.
    static func chordLabel(of scope: Scope) -> String {
        guard case .one(let layer) = scope else { return "" }
        return layer.label
    }

    /// What macOS uses a key for under the SHOWN scope, or nil
    /// where the board draws no reserved mark (#798).
    ///
    /// Keyed on `scope`, never on the selected set: `.all` draws
    /// no reserved marks by ruling — macOS reserves a
    /// COMBINATION, so the answer has no meaning until a chip
    /// picks one — and a sentence naming an owner there is the
    /// words asserting what the picture refuses to draw.
    static func reservedOwner(
        of code: UInt32,
        scope: Scope
    ) -> SystemShortcut? {
        guard case .one(let layer) = scope,
            reservedKeys(scope: scope).contains(code)
        else { return nil }
        let combo = SystemShortcuts.map.keys.first {
            $0.keyCode == code
                && ModifierLayer(modifiers: $0.modifiers) == layer
        }
        return combo.flatMap { SystemShortcuts.map[$0] }
    }

    /// User bindings conflicting with macOS reservations.
    static func overwrittenReserved(
        claims: [UInt32: [ModifierLayer]],
        scope: Scope
    ) -> Set<UInt32> {
        reservedKeys(scope: scope).filter {
            claims[$0]?.isEmpty == false
        }
    }

    /// System-reserved keys still free under shown modifier (#1094).
    static func reservedUnbound(
        claims: [UInt32: [ModifierLayer]],
        scope: Scope
    ) -> Set<UInt32> {
        reservedKeys(scope: scope).filter {
            claims[$0]?.isEmpty != false
        }
    }
}
