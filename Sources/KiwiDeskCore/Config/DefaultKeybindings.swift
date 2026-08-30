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
        // Tier 2 — ⌃⌥⇧: swap window / move to space
        for (dir, phrase) in directions {
            rows.append(
                KeyBinding(
                    combo: "control+option+shift+\(dir)",
                    lua: "KiwiDesk.swap(\"\(dir)\")",
                    kind: .navigation,
                    label: "Swap with window \(phrase)"
                )
            )
        }
        for (digit, space) in numbered(spaces) {
            rows.append(moveSpaceRow(digit: digit, space: space))
        }
        // Tier 3 — ⌃⌥⌘: move to space and follow
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
        rows.append(showShortcutsRow())
        return rows
    }

    /// ⌃⌥K row that opens the Shortcuts panel (#602). Seeded into
    /// the base mode here AND into every GUI-created mode
    /// (`ShortcutsHeader.addMode`), so the cheat-sheet stays
    /// keyboard-reachable in any mode.
    public static func showShortcutsRow() -> KeyBinding {
        KeyBinding(
            combo: "control+option+k",
            lua: "KiwiDesk.show_shortcuts()",
            kind: .navigation,
            label: "Show shortcuts panel"
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

    /// Additive top-up of missing space digit rows (#485) — a
    /// combo already bound is left untouched, so the top-up can
    /// never overwrite. Combo identity is by parsed `KeyCombo`,
    /// so a hand-authored alias (`ctrl+alt+6`) counts as taken.
    public static func digitTopUp(
        existing: [KeyBinding],
        spaces: [SpaceID]
    ) -> [KeyBinding] {
        let taken = Set(
            existing.compactMap {
                KeyCombo.parse($0.combo)
            }
        )
        let isFree: (KeyBinding) -> Bool = { row in
            guard let combo = KeyCombo.parse(row.combo) else {
                return false
            }
            return !taken.contains(combo)
        }
        var rows: [KeyBinding] = []
        for (digit, space) in numbered(spaces) {
            let candidates = [
                focusSpaceRow(digit: digit, space: space),
                moveSpaceRow(digit: digit, space: space),
                followSpaceRow(digit: digit, space: space),
            ]
            rows.append(contentsOf: candidates.filter(isFree))
        }
        return rows
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
