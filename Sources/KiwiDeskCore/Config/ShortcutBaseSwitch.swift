import Foundation

/// The "Shortcuts use" switch (#2460): moves every row the
/// `ShortcutBase.moved` mapping covers onto `base`, in every layer of
/// `config`, and sets the base — the rows and the base in one draft
/// write. Pure over the config; the GUI stages it, Save writes it.
/// The ruling is `docs/design-decisions.md` ▸ *One switch puts
/// KiwiDesk's shortcuts on `⌃⌥` or on `✦`*.
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

    /// `config` with its rows moved onto `base` and the base set;
    /// returns the rows a holder kept.
    @discardableResult
    public static func apply(
        _ base: ShortcutBase,
        to config: inout GuiConfig
    ) -> [Kept] {
        var kept: [Kept] = []
        for index in config.layers.indices {
            let layer = config.layers[index]
            let (rows, refused) = moved(layer.bindings, onto: base)
            config.layers[index].bindings = rows
            kept += refused.map {
                Kept(
                    layer: layer.name,
                    row: $0.row,
                    target: $0.target,
                    holder: $0.holder
                )
            }
        }
        config.shortcutBase = base
        NavigationChords.deduplicate(&config)
        return kept
    }

    /// The rows the switch would leave on the other base, read off
    /// `rows` as they stand: a holder keeps each.
    public static func kept(
        _ rows: [KeyBinding],
        onto base: ShortcutBase
    ) -> [(row: KeyBinding, target: String, holder: KeyBinding)] {
        moved(rows, onto: base).refused
    }

    private static func moved(
        _ rows: [KeyBinding],
        onto base: ShortcutBase
    ) -> (
        rows: [KeyBinding],
        refused: [(row: KeyBinding, target: String, holder: KeyBinding)]
    ) {
        let targets: [KeyCombo?] = rows.map {
            KeyCombo.parse($0.combo).flatMap {
                ShortcutBase.moved($0, to: base)
            }
        }
        var out = rows
        var refused: [(KeyBinding, String, KeyBinding)] = []
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
                refused.append((rows[index], text, rows[holder]))
            } else {
                out[index].combo = text
            }
        }
        return (out, refused)
    }
}
