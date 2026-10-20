import Foundation

/// The "Shortcuts use" switch (#2460): moves every row the
/// `ShortcutBase.moved` mapping covers onto `base`, in every layer of
/// `config`, and sets the base — the rows and the base in one draft
/// write. Pure over the config; the GUI stages it, Save writes it.
/// A narration of the draft takes the same replay, so the rows the
/// switch moved read as the switch's own change (`explains`). The
/// ruling is `docs/design-decisions.md` ▸ *One switch puts KiwiDesk's
/// shortcuts on `⌃⌥` or on `✦`*.
public enum ShortcutBaseSwitch {
    /// A row the switch could move and did not: another row of its
    /// layer holds the target, compared as registered.
    public struct Kept: Equatable, Sendable {
        public let layer: String
        public let row: KeyBinding
        /// The chord the row would take, in the stored spelling.
        public let target: String
        public let holder: KeyBinding
    }

    /// `config` with its rows moved onto `base` and the base set.
    public static func apply(
        _ base: ShortcutBase,
        to config: inout GuiConfig
    ) {
        let live = Set(config.spaces)
        config.layers = config.layers.map {
            move($0, onto: base, liveSpaces: live) { _ in false }.layer
        }
        config.shortcutBase = base
    }

    /// The rows of `layer` the switch would leave where they are,
    /// each with the row that holds its target.
    public static func kept(
        _ layer: KeyLayer,
        onto base: ShortcutBase
    ) -> [Kept] {
        moved(layer, onto: base).kept
    }

    /// Whether `new` is `old` moved onto `base` — a change the switch
    /// made rather than one the user did.
    public static func explains(
        old: String?,
        new: String?,
        onto base: ShortcutBase
    ) -> Bool {
        guard let old, let new, let combo = KeyCombo.parse(old),
            let target = ShortcutBase.moved(combo, to: base)
        else { return false }
        return KeyCombo.parse(new) == target
    }

    /// `layer` with its rows moved onto `base` — `staying` rows left
    /// where they are, holding their chords — and then deduplicated
    /// against `liveSpaces`, with each moved row by its old chord.
    /// The draft's switch and the shared keymap's move (#2460) both
    /// take it, so the two cannot write different rows.
    public static func move(
        _ layer: KeyLayer,
        onto base: ShortcutBase,
        liveSpaces: Set<SpaceID>,
        staying: (KeyBinding) -> Bool
    ) -> (layer: KeyLayer, moves: [String: KeyBinding]) {
        let rows = moved(layer, onto: base, staying: staying).rows
        var moves: [String: KeyBinding] = [:]
        for (old, new) in zip(layer.bindings, rows)
        where old.combo != new.combo {
            moves[old.combo] = new
        }
        var layer = layer
        layer.bindings =
            NavigationChords.deduplicated(
                rows,
                liveSpaces: liveSpaces
            ).rows
        return (layer, moves)
    }

    private static func moved(
        _ layer: KeyLayer,
        onto base: ShortcutBase,
        staying: (KeyBinding) -> Bool = { _ in false }
    ) -> (rows: [KeyBinding], kept: [Kept]) {
        let rows = layer.bindings
        let targets: [KeyCombo?] = rows.map { row in
            staying(row)
                ? nil
                : KeyCombo.parse(row.combo).flatMap {
                    ShortcutBase.moved($0, to: base)
                }
        }
        var out = rows
        var kept: [Kept] = []
        for (index, target) in targets.enumerated() {
            guard let target, let text = target.comboString() else {
                continue
            }
            // A holder is a row that stays: the movers' own chords
            // leave, and the mapping sends no two rows to one chord.
            let holder = rows.indices.first {
                targets[$0] == nil
                    && KeyCombo.parse(rows[$0].combo)?.registered
                        == target.registered
            }
            if let holder {
                kept.append(
                    Kept(
                        layer: layer.name,
                        row: rows[index],
                        target: text,
                        holder: rows[holder]
                    )
                )
            } else {
                out[index].combo = text
            }
        }
        return (out, kept)
    }
}
