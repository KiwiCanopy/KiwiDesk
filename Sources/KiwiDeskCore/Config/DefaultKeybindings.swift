import Foundation

/// The first-run starter shortcuts (#91): the set seeded into
/// the base `default` mode when no binding exists anywhere —
/// a fresh install, or a config whose Lua declares none — so a
/// new user can focus, move, and navigate windows immediately.
///
/// Modifier scheme (#270): every default is built on **Control+
/// Option**, escalating ⌃⌥ → ⌃⌥⇧ → ⌃⌥⌘. Bare Option is the
/// macOS special-character (AltGr) modifier, so a global
/// `option+<key>` hotkey swallows characters on international
/// Apple keyboards (⌥L = @, ⌥5 = [ …); adding Control or Command
/// suppresses that composition, so ⌃⌥ is the lightest text-safe
/// chord. Directions bind the **arrow keys**, which are layout-
/// stable and never compose a character.
///
/// The Lua and canonical labels mirror what
/// `KeybindingCatalog` (GUI target) authors for the same
/// spaces and resize step — byte-for-byte, or the import
/// classifier would demote the rows to Custom (#4). That
/// mirror is guarded by `DefaultSeedCatalogParityTests`
/// (GUI tests), which iterates every seeded row and matches
/// it against the catalog's output.
///
/// Per-space rows are position-based (`control+option+1` targets
/// the FIRST space in display order, whatever its name),
/// generated only for the spaces that exist at seed time and
/// capped at nine — so no dead row targeting a nonexistent space
/// is ever authored (#91).
public enum DefaultKeybindings {
    /// Direction ↔ canonical label phrase, in the catalog's
    /// order (left, down, up, right). The arrow key that drives
    /// each binding is the direction itself — `control+option+
    /// left` focuses left — so one token serves both the combo
    /// and the Lua argument.
    private static let directions = [
        ("left", "to the left"),
        ("down", "below"),
        ("up", "above"),
        ("right", "to the right"),
    ]

    /// The starter rows for the base `default` mode.
    public static func bindings(
        spaces: [SpaceID],
        resizeStep: Int
    ) -> [KeyBinding] {
        var rows: [KeyBinding] = []
        // Tier 1 — ⌃⌥: focus a window, go to a space.
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
        for (offset, space) in numbered(spaces) {
            rows.append(
                KeyBinding(
                    combo: "control+option+\(offset)",
                    lua: "KiwiDesk.focus_space"
                        + "(\(SpaceLuaArg.quote(space.raw)))",
                    kind: .navigation,
                    label: "Go to Space \(space.raw)"
                )
            )
        }
        // Tier 2 — ⌃⌥⇧: swap a window, move it to a space.
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
        for (offset, space) in numbered(spaces) {
            rows.append(
                KeyBinding(
                    combo: "control+option+shift+\(offset)",
                    lua: "KiwiDesk.move_to_space"
                        + "(\(SpaceLuaArg.quote(space.raw)))",
                    kind: .navigation,
                    label: "Move to Space \(space.raw)"
                )
            )
        }
        // Tier 3 — ⌃⌥⌘: resize, move-to-space-and-follow.
        rows.append(contentsOf: resizeRows(step: resizeStep))
        for (offset, space) in numbered(spaces) {
            rows.append(
                KeyBinding(
                    combo: "control+option+command+\(offset)",
                    lua: "KiwiDesk.move_to_space_and_follow"
                        + "(\(SpaceLuaArg.quote(space.raw)))",
                    kind: .navigation,
                    label: "Move to Space \(space.raw) & follow"
                )
            )
        }
        // Toggles — mnemonic letters. Display sticky is the more
        // frequent scope, so it takes the lighter ⌃⌥ chord; the
        // broader global sticky escalates to ⌃⌥⇧.
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
                lua: "KiwiDesk.toggle_display_sticky()",
                kind: .navigation,
                label: "Toggle display sticky"
            )
        )
        rows.append(
            KeyBinding(
                combo: "control+option+shift+s",
                lua: "KiwiDesk.toggle_sticky()",
                kind: .navigation,
                label: "Toggle sticky"
            )
        )
        return rows
    }

    /// The four ⌃⌥⌘ + arrow resize rows: the arrow points the
    /// change — →/← grow/shrink width, ↑/↓ grow/shrink height —
    /// by the configurable `resize.step` (#58).
    private static func resizeRows(step: Int) -> [KeyBinding] {
        [
            KeyBinding(
                combo: "control+option+command+right",
                lua: "KiwiDesk.resize(\"x\", \(step))",
                kind: .navigation,
                label: "Grow width"
            ),
            KeyBinding(
                combo: "control+option+command+left",
                lua: "KiwiDesk.resize(\"x\", -\(step))",
                kind: .navigation,
                label: "Shrink width"
            ),
            KeyBinding(
                combo: "control+option+command+up",
                lua: "KiwiDesk.resize(\"y\", \(step))",
                kind: .navigation,
                label: "Grow height"
            ),
            KeyBinding(
                combo: "control+option+command+down",
                lua: "KiwiDesk.resize(\"y\", -\(step))",
                kind: .navigation,
                label: "Shrink height"
            ),
        ]
    }

    /// The first nine spaces paired with their 1-based display
    /// position — the digit each per-space combo uses.
    private static func numbered(
        _ spaces: [SpaceID]
    ) -> [(Int, SpaceID)] {
        spaces.prefix(9).enumerated().map { ($0 + 1, $1) }
    }
}
