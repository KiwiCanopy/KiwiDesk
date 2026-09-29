import Foundation

/// First-run starter keyboard shortcuts (#91, #270, #1075, #1056).
/// Parity guarded by `DefaultSeedCatalogParityTests`.
public enum DefaultKeybindings {
    private static let directions = [
        ("left", "to the left"),
        ("down", "below"),
        ("up", "above"),
        ("right", "to the right"),
    ]

    /// Starter keybindings for base `default` mode (#91, #466, #1094, #602).
    public static func bindings(
        spaces: [SpaceID],
        resizeStep: Int
    ) -> [KeyBinding] {
        var rows: [KeyBinding] = []
        // Tier 1 — ⌃⌥: focus window / space
        for (dir, phrase) in directions {
            rows.append(
                KeyBinding(
                    combo: "control+option+\(dir)",
                    lua: "KiwiDesk.focus(\"\(dir)\")",
                    kind: .navigation,
                    label: "Focus window \(phrase)"
                )
            )
        }
        for (digit, space) in numbered(spaces) {
            rows.append(focusSpaceRow(digit: digit, space: space))
        }
        // Tier 2 — ⌃⌥⇧: move to space
        for (digit, space) in numbered(spaces) {
            rows.append(moveSpaceRow(digit: digit, space: space))
        }
        // Tier 3 — ⌃⌥⌘: swap window / move to space and follow
        for (dir, phrase) in directions {
            rows.append(
                KeyBinding(
                    combo: "control+option+command+\(dir)",
                    lua: "KiwiDesk.swap(\"\(dir)\")",
                    kind: .navigation,
                    label: "Swap with window \(phrase)"
                )
            )
        }
        for (digit, space) in numbered(spaces) {
            rows.append(followSpaceRow(digit: digit, space: space))
        }
        // Size — ⌥⌘ (#1075)
        rows.append(contentsOf: resizeRows(step: resizeStep))
        // Toggles — ⌃⌥ (#1094)
        rows.append(
            KeyBinding(
                combo: "control+option+f",
                lua: "KiwiDesk.toggle_floating()",
                kind: .navigation,
                label: "Toggle floating"
            )
        )
        rows.append(
            KeyBinding(
                combo: "control+option+s",
                lua: "KiwiDesk.toggle_sticky()",
                kind: .navigation,
                label: "Toggle sticky"
            )
        )
        rows.append(
            KeyBinding(
                combo: "control+option+p",
                lua: "KiwiDesk.toggle_display_sticky()",
                kind: .navigation,
                label: "Toggle display sticky"
            )
        )
        rows.append(contentsOf: appChromeRows())
        return rows
    }

    /// The app-chrome rows on the `⌃⌥` base — ⌃⌥K opens the
    /// Shortcuts panel (#602), ⌃⌥, opens Settings (#1381) —
    /// seeded into the base layer here and into every
    /// GUI-created layer (`LayerChromeSeedTests`).
    public static func appChromeRows() -> [KeyBinding] {
        [showShortcutsRow(), openSettingsRow()]
    }

    public static func showShortcutsRow() -> KeyBinding {
        KeyBinding(
            combo: "control+option+k",
            lua: "KiwiDesk.show_shortcuts()",
            kind: .navigation,
            label: "Show shortcuts panel"
        )
    }

    public static func openSettingsRow() -> KeyBinding {
        KeyBinding(
            combo: "control+option+comma",
            lua: "KiwiDesk.open_settings()",
            kind: .navigation,
            label: "Open Settings"
        )
    }

    private static func focusSpaceRow(
        digit: String,
        space: SpaceID
    ) -> KeyBinding {
        KeyBinding(
            combo: "control+option+\(digit)",
            lua: "KiwiDesk.focus_space"
                + "(\(SpaceLuaArg.quote(space.raw)))",
            kind: .navigation,
            label: "Go to Space \(space.raw)"
        )
    }

    private static func moveSpaceRow(
        digit: String,
        space: SpaceID
    ) -> KeyBinding {
        KeyBinding(
            combo: "control+option+shift+\(digit)",
            lua: "KiwiDesk.move_to_space"
                + "(\(SpaceLuaArg.quote(space.raw)))",
            kind: .navigation,
            label: "Move to Space \(space.raw)"
        )
    }

    private static func followSpaceRow(
        digit: String,
        space: SpaceID
    ) -> KeyBinding {
        KeyBinding(
            combo: "control+option+command+\(digit)",
            lua: "KiwiDesk.move_to_space_and_follow"
                + "(\(SpaceLuaArg.quote(space.raw)))",
            kind: .navigation,
            label: "Move to Space \(space.raw) & follow"
        )
    }

    /// Additive top-up of missing space digit rows (#485, #1797):
    /// each Space verb with no row in `existing` takes its digit
    /// when that combo is free, and otherwise stays unbound. A
    /// Space named 1–10 claims its own number first; any other
    /// takes its place among the first ten. Combo identity is by
    /// parsed `KeyCombo`, so `ctrl+alt+6` counts as taken.
    public static func digitTopUp(
        existing: [KeyBinding],
        spaces: [SpaceID]
    ) -> [KeyBinding] {
        var taken = Set(
            existing.compactMap {
                KeyCombo.parse($0.combo)
            }
        )
        let bound = Set(
            existing.compactMap { SpaceLuaArg.target(of: $0.lua) }
        )
        let slots = topUpDigits(spaces)
        // A numbered Space's own digit stays its own even when that
        // Space needs nothing, so a positional Space never takes it.
        let reserved = Set(
            slots.filter(\.own).flatMap {
                candidates(digit: $0.digit, space: $0.space)
                    .compactMap { KeyCombo.parse($0.combo) }
            }
        )
        var rows: [KeyBinding] = []
        for slot in slots {
            for row in candidates(digit: slot.digit, space: slot.space) {
                guard let combo = KeyCombo.parse(row.combo),
                    let action = SpaceLuaArg.target(of: row.lua),
                    !bound.contains(action),
                    slot.own || !reserved.contains(combo),
                    taken.insert(combo).inserted
                else { continue }
                rows.append(row)
            }
        }
        return rows
    }

    private static func candidates(
        digit: String,
        space: SpaceID
    ) -> [KeyBinding] {
        [
            focusSpaceRow(digit: digit, space: space),
            moveSpaceRow(digit: digit, space: space),
            followSpaceRow(digit: digit, space: space),
        ]
    }

    /// The digit each Space tops up on: a Space named 1–10 its own
    /// number (`0` for 10), listed first so no other Space can take
    /// it; any other Space its position within the capacity.
    private static func topUpDigits(
        _ spaces: [SpaceID]
    ) -> [(digit: String, space: SpaceID, own: Bool)] {
        let range = 1...digitCapacity
        let own: [(Int, SpaceID)] = spaces.compactMap { space in
            Int(space.raw).flatMap {
                range.contains($0) ? ($0, space) : nil
            }
        }
        let owners = Set(own.map(\.1))
        let positional: [(Int, SpaceID)] = spaces.enumerated().compactMap {
            owners.contains($0.element) || !range.contains($0.offset + 1)
                ? nil : ($0.offset + 1, $0.element)
        }
        let digit = { (number: Int) in
            number == digitCapacity ? "0" : String(number)
        }
        return own.map { (digit($0.0), $0.1, true) }
            + positional.map { (digit($0.0), $0.1, false) }
    }

    /// Maximum spaces with default digit shortcuts (1...9, 0) (#466).
    public static let digitCapacity = 10

    private static func numbered(
        _ spaces: [SpaceID]
    ) -> [(String, SpaceID)] {
        spaces.prefix(digitCapacity).enumerated().map {
            index,
            space in
            (
                index == digitCapacity - 1
                    ? "0" : String(index + 1),
                space
            )
        }
    }
}
