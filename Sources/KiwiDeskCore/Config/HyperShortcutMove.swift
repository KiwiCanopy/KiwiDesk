import Foundation

/// The Hyper key's one-shot offer (#1870): move the seeded `⌃⌥`
/// letter rows onto Hyper, and the reverse. Pure over a layer's
/// rows; the list is read off the seed, never typed. The ruling is
/// `docs/design-decisions.md` ▸ *The Hyper move is an offer*.
public enum HyperShortcutMove {
    public enum Direction: Sendable, Equatable {
        /// `⌃⌥` + key → `✦` + key, the Desktop tier onto `✦`.
        case toHyper
        /// The reverse, offered once Hyper is off.
        case back
    }

    /// One row changing chord, in the stored spelling.
    public struct Move: Equatable, Sendable {
        public let lua: String
        public let from: String
        public let to: String
    }

    /// One line of the offer: a seeded row, or KiwiHub's sides with
    /// Open Settings, which move together or not at all.
    public struct Item: Equatable, Sendable, Identifiable {
        /// The first seeded row's Lua.
        public let id: String
        /// The seeded rows the line stands for, in seed order.
        public let seeds: [KeyBinding]
        public let moves: [Move]
        /// Whether every row is on its seeded chord — ticked by
        /// default; a rebound row is listed unticked.
        public let seeded: Bool
        /// The row already on a chord the line would take, which
        /// refuses the whole line.
        public let taken: KeyBinding?
    }

    /// A seeded row whose new chord another row holds: it stays.
    public struct Kept: Equatable, Sendable {
        public let move: Move
        public let holder: KeyBinding
    }

    /// The Go to Desktop line: the rows on their seeded chord whose
    /// new chord is free, and the base it sets.
    public struct DesktopLine: Equatable, Sendable {
        public let moves: [Move]
        public let kept: [Kept]
        /// The base the line leaves and the one it sets.
        public let from: DesktopShortcutBase
        public let base: DesktopShortcutBase
    }

    public struct Offer: Equatable, Sendable {
        public let items: [Item]
        /// Nil once the Desktop base is already where this
        /// direction would put it.
        public let desktop: DesktopLine?
        public var isEmpty: Bool { items.isEmpty && desktop == nil }
    }

    /// The offer `rows` (one layer's) earn under `base`.
    public static func offer(
        _ direction: Direction,
        rows: [KeyBinding],
        base: DesktopShortcutBase
    ) -> Offer {
        let seeds = letterSeed
        let lone = seeds.filter { !isChrome($0) }.map { [$0] }
        let groups = lone + [seeds.filter(isChrome)]
        let items = groups.compactMap {
            item(for: $0, direction, rows: rows)
        }
        // Forward, the Desktop line rides the letter offer and
        // retires with it, declined or not.
        let lettersLeft = direction == .back || !items.isEmpty
        return Offer(
            items: items,
            desktop: lettersLeft
                ? desktopLine(direction, rows: rows, base: base) : nil
        )
    }

    /// `config` with exactly the moves `offer` showed: each picked
    /// line, and with `desktop` the Desktop line and its base. A
    /// row moves in every layer that holds it on the chord shown,
    /// a line as one unit, and never where another row of that
    /// layer holds a chord it would take.
    public static func apply(
        _ offer: Offer,
        items picked: Set<String>,
        desktop: Bool,
        to config: inout GuiConfig
    ) {
        var units = offer.items.filter {
            picked.contains($0.id) && $0.taken == nil
        }.map(\.moves)
        if desktop, let line = offer.desktop {
            units += line.moves.map { [$0] }
            config.desktopShortcutBase = line.base
        }
        for index in config.layers.indices {
            var rows = config.layers[index].bindings
            for unit in units { move(unit, in: &rows) }
            config.layers[index].bindings = rows
        }
        NavigationChords.deduplicate(&config)
    }

    /// Moves the rows of `unit` this layer holds on their shown
    /// chord, or none of them where one's new chord is taken.
    private static func move(_ unit: [Move], in rows: inout [KeyBinding]) {
        let found = unit.compactMap { move in
            rows.firstIndex {
                $0.kind == .navigation && $0.lua == move.lua
                    && KeyCombo.equivalent($0.combo, move.from)
            }.map { ($0, move) }
        }
        guard !found.isEmpty,
            holder(of: found.map(\.1), in: rows) == nil
        else { return }
        for (row, move) in found { rows[row].combo = move.to }
    }

    /// The seed's `⌃⌥` rows off the arrow and digit ladder, in seed
    /// order — the letters, the `⇧` reversal and the comma.
    public static var letterSeed: [KeyBinding] {
        DefaultKeybindings.bindings(spaces: [], resizeStep: 1).filter {
            guard let combo = KeyCombo.parse($0.combo) else { return false }
            return moved(combo, .toHyper) != nil && !isLadder(combo)
        }
    }

    /// `row` on the base the seeded letters of `rows` sit on: a
    /// seeded `⌃⌥` letter row lands on `✦` where more of those
    /// letters are on Hyper than on `⌃⌥`, so a default added after
    /// the move joins its letters (#2303). Anything else is `row`.
    public static func onLettersBase(
        _ row: KeyBinding,
        in rows: [KeyBinding]
    ) -> KeyBinding {
        let seeds = letterSeed
        guard seeds.contains(where: { $0.lua == row.lua }),
            let combo = KeyCombo.parse(row.combo),
            let target = moved(combo, .toHyper)?.comboString()
        else { return row }
        var hyper = 0
        var base = 0
        for seed in seeds {
            guard
                let found = rows.first(where: {
                    $0.kind == .navigation
                        && NavigationChords.sameAction($0, seed)
                }),
                let combo = KeyCombo.parse(found.combo)
            else { continue }
            if combo.modifiers.contains(.hyper) {
                hyper += 1
            } else if moved(combo, .toHyper) != nil {
                base += 1
            }
        }
        guard hyper > base else { return row }
        var onHyper = row
        onHyper.combo = target
        return onHyper
    }

    /// The base the seeded letters sit on and the offer moves from.
    static let letterBase: HotkeyModifiers = [.control, .option]

    /// `combo` on the other base, or nil where it is not on the
    /// base `direction` moves from.
    static func moved(_ combo: KeyCombo, _ direction: Direction) -> KeyCombo? {
        let base = letterBase
        let modifiers = combo.modifiers
        switch direction {
        case .toHyper:
            guard modifiers.isSuperset(of: base),
                modifiers.isDisjoint(with: [.command, .hyper])
            else { return nil }
            return KeyCombo(
                keyCode: combo.keyCode,
                modifiers: modifiers.subtracting(base).union(.hyper)
            )
        case .back:
            guard modifiers.contains(.hyper),
                modifiers.isDisjoint(with: base.union(.command))
            else { return nil }
            return KeyCombo(
                keyCode: combo.keyCode,
                modifiers: modifiers.subtracting(.hyper).union(base)
            )
        }
    }

    private static func item(
        for seeds: [KeyBinding],
        _ direction: Direction,
        rows: [KeyBinding]
    ) -> Item? {
        var moves: [Move] = []
        var seeded = true
        for seed in seeds {
            guard
                let row = rows.first(where: {
                    $0.kind == .navigation
                        && NavigationChords.sameAction($0, seed)
                }),
                let combo = KeyCombo.parse(row.combo),
                let target = moved(combo, direction),
                let to = target.comboString()
            else { continue }
            if combo != seededChord(of: seed, direction) { seeded = false }
            moves.append(Move(lua: row.lua, from: row.combo, to: to))
        }
        guard let first = seeds.first, !moves.isEmpty else { return nil }
        return Item(
            id: first.lua,
            seeds: seeds,
            moves: moves,
            seeded: seeded,
            taken: holder(of: moves, in: rows)
        )
    }

    /// The seed's own chord as it reads on the base `direction`
    /// moves from.
    private static func seededChord(
        of seed: KeyBinding,
        _ direction: Direction
    ) -> KeyCombo? {
        guard let combo = KeyCombo.parse(seed.combo) else { return nil }
        return direction == .toHyper ? combo : moved(combo, .toHyper)
    }

    /// The first row outside `moves` already on a chord one of them
    /// takes, compared as registered (a held Hyper row is its bare
    /// chord, as the conflict check reads it).
    static func holder(
        of moves: [Move],
        in rows: [KeyBinding]
    ) -> KeyBinding? {
        let movers = Set(moves.map(\.lua))
        let targets = Set(
            moves.compactMap { KeyCombo.parse($0.to)?.registered }
        )
        return rows.first {
            !movers.contains($0.lua)
                && KeyCombo.parse($0.combo).map {
                    targets.contains($0.registered)
                } == true
        }
    }

    /// KiwiHub's sides and the app chrome they travel with.
    static func isChrome(_ row: KeyBinding) -> Bool {
        let lua =
            KiwiHubSide.allCases.map(\.lua)
            + DefaultKeybindings.appChromeRows().map(\.lua)
        return lua.contains(row.lua)
    }

    /// Whether `combo` is on the arrow or digit ladder.
    static func isLadder(_ combo: KeyCombo) -> Bool {
        guard let name = KeyCombo.keyName(for: combo.keyCode) else {
            return false
        }
        return ["left", "right", "up", "down"].contains(name)
            || Int(name) != nil
    }
}
