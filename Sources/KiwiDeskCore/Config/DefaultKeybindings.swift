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

    /// Additive top-up of missing space digit rows (#485): a Space
    /// verb with no row of its own takes its digit when that combo
    /// is free, and otherwise stays unbound. It asks per ACTION,
    /// never per free digit, so a reordered list cannot hand a
    /// Space a second chord (#1797). Combo identity is by parsed
    /// `KeyCombo`, so `ctrl+alt+6` counts as taken.
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
        var rows: [KeyBinding] = []
        for (index, space) in spaces.enumerated() {
            guard let digit = topUpDigit(of: space, at: index)
            else { continue }
            let candidates = [
                focusSpaceRow(digit: digit, space: space),
                moveSpaceRow(digit: digit, space: space),
                followSpaceRow(digit: digit, space: space),
            ]
            for row in candidates {
                guard let combo = KeyCombo.parse(row.combo),
                    let action = SpaceLuaArg.target(of: row.lua),
                    !bound.contains(action),
                    taken.insert(combo).inserted
                else { continue }
                rows.append(row)
            }
        }
        return rows
    }

    /// The digit a top-up gives `space`: its own number when it is
    /// named 1–10 (`0` for 10), so a reorder cannot move it, and
    /// otherwise its position within the digit capacity (#1797).
    private static func topUpDigit(
        of space: SpaceID,
        at index: Int
    ) -> String? {
        let number = Int(space.raw) ?? (index + 1)
        guard (1...digitCapacity).contains(number) else {
            return nil
        }
        return number == digitCapacity ? "0" : String(number)
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
