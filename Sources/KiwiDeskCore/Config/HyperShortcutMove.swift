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
        return Offer(
            items: items,
            desktop: desktopLine(direction, rows: rows, base: base)
        )
    }

    /// `config` with the picked lines moved in every layer — a
    /// line refused in a layer stays there — and, with `desktop`,
    /// the Desktop rows and the base moved too.
    public static func apply(
        _ direction: Direction,
        items picked: Set<String>,
        desktop: Bool,
        to config: inout GuiConfig
    ) {
        let base = config.desktopShortcutBase
        var target: DesktopShortcutBase?
        for index in config.layers.indices {
            var rows = config.layers[index].bindings
            let offer = offer(direction, rows: rows, base: base)
            var moves = offer.items.filter {
                picked.contains($0.id) && $0.taken == nil
            }.flatMap(\.moves)
            if desktop, let line = offer.desktop {
                moves += line.moves
                target = line.base
            }
            for move in moves {
                guard
                    let row = rows.firstIndex(where: {
                        $0.kind == .navigation && $0.lua == move.lua
                            && $0.combo == move.from
                    })
                else { continue }
                rows[row].combo = move.to
            }
            config.layers[index].bindings = rows
        }
        if let target { config.desktopShortcutBase = target }
        NavigationChords.deduplicate(&config)
    }

    /// The seed's `⌃⌥` rows off the arrow and digit ladder, in seed
    /// order — the letters, the `⇧` reversal and the comma.
    public static var letterSeed: [KeyBinding] {
        DefaultKeybindings.bindings(spaces: [], resizeStep: 1).filter {
            guard let combo = KeyCombo.parse($0.combo) else { return false }
            return moved(combo, .toHyper) != nil && !isLadder(combo)
        }
    }

    /// `combo` on the other base, or nil where it is not on the
    /// base `direction` moves from.
    static func moved(_ combo: KeyCombo, _ direction: Direction) -> KeyCombo? {
        let base: HotkeyModifiers = [.control, .option]
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
    private static func holder(
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

    private static func desktopLine(
        _ direction: Direction,
        rows: [KeyBinding],
        base: DesktopShortcutBase
    ) -> DesktopLine? {
        let toHyper = direction == .toHyper
        let from: DesktopShortcutBase = toHyper ? .standard : .hyper
        let to: DesktopShortcutBase = toHyper ? .hyper : .standard
        guard base == from else { return nil }
        var moves: [Move] = []
        var kept: [Kept] = []
        for number in 1...DefaultKeybindings.digitCapacity {
            guard
                let seeded = DefaultKeybindings.desktopRow(number, base: from),
                let next = DefaultKeybindings.desktopRow(number, base: to),
                let row = rows.first(where: {
                    $0.lua == seeded.lua
                        && KeyCombo.equivalent($0.combo, seeded.combo)
                })
            else { continue }
            let move = Move(lua: row.lua, from: row.combo, to: next.combo)
            if let holder = holder(of: [move], in: rows) {
                kept.append(Kept(move: move, holder: holder))
            } else {
                moves.append(move)
            }
        }
        return DesktopLine(moves: moves, kept: kept, from: from, base: to)
    }

    /// KiwiHub's sides and the app chrome they travel with.
    private static func isChrome(_ row: KeyBinding) -> Bool {
        let lua =
            KiwiHubSide.allCases.map(\.lua)
            + DefaultKeybindings.appChromeRows().map(\.lua)
        return lua.contains(row.lua)
    }

    private static func isLadder(_ combo: KeyCombo) -> Bool {
        guard let name = KeyCombo.keyName(for: combo.keyCode) else {
            return false
        }
        return ["left", "right", "up", "down"].contains(name)
            || Int(name) != nil
    }
}
