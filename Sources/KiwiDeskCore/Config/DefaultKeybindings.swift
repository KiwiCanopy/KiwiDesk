import Foundation

/// The first-run starter shortcuts (#91): the set seeded into
/// the base `default` mode when no binding exists anywhere —
/// a fresh install, or a config whose Lua declares none — so a
/// new user can focus, move, and navigate windows immediately.
///
/// Modifier scheme (#270, amended by #1075): the **positional**
/// defaults are built on **Control+Option**, escalating ⌃⌥ (act
/// on the focus) → ⌃⌥⇧ (act on the window) → ⌃⌥⌘ (both), so
/// `⌘` there means exactly one thing: "and follow". **Size takes a
/// base of its own, ⌥⌘**, because it is not a positional verb —
/// it changes a weight or a scroll-slot domain rather than a
/// place in the flat array — and because it is the one verb a
/// user HOLDS (#1056), which ⌥⌘ takes as a single thumb roll and
/// ⌃⌥⌘ does not.
///
/// Bare Option is the macOS special-character (AltGr) modifier,
/// so a global `option+<key>` hotkey swallows characters on
/// international Apple keyboards (⌥L = @, ⌥5 = [ …); adding
/// Control **or Command** suppresses that composition, which is
/// what makes ⌥⌘ text-safe as well as ⌃⌥. Directions bind the
/// **arrow keys**, which are layout-stable and never compose a
/// character; size binds **digits**, which hold their physical
/// position on every layout and are the only keys a numeric
/// keypad will be able to repeat once #1074 lands.
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
/// capped at ten — positions 1…9 then ⌃⌥0 for the tenth (#466) —
/// so no dead row targeting a nonexistent space is ever authored
/// (#91).
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
        for (digit, space) in numbered(spaces) {
            rows.append(focusSpaceRow(digit: digit, space: space))
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
        for (digit, space) in numbered(spaces) {
            rows.append(moveSpaceRow(digit: digit, space: space))
        }
        // Tier 3 — ⌃⌥⌘: move-to-space-and-follow.
        for (digit, space) in numbered(spaces) {
            rows.append(followSpaceRow(digit: digit, space: space))
        }
        // Size — ⌥⌘, a base of its own rather than a rung on the
        // positional ladder (#1075).
        rows.append(contentsOf: resizeRows(step: resizeStep))
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
        // General — open the read-only Shortcuts panel. App
        // chrome, not a workspace verb, so it comes last (#602).
        rows.append(showShortcutsRow())
        return rows
    }

    /// The ⌃⌥K row that opens the read-only Shortcuts panel
    /// (#602) — a GUI/app action, not a workspace verb. "K = Keys"
    /// names a shortcuts cheat-sheet; ⌃⌥H was avoided because
    /// `⌘H` = Hide reads as *Hide* first to a Mac user. Seeded
    /// into the base mode (here) and into every mode created in
    /// the GUI (`ShortcutsHeader.addMode`), so the cheat-sheet is
    /// reachable from the keyboard in any mode — editable or
    /// deletable per mode like any default, with the menu bar's
    /// "View Shortcuts…" as the mode-independent fallback. Its Lua
    /// and label mirror `KeybindingCatalog.showShortcuts`
    /// byte-for-byte (guarded by `DefaultSeedCatalogParityTests`),
    /// so an imported copy classifies back to `.navigation`.
    public static func showShortcutsRow() -> KeyBinding {
        KeyBinding(
            combo: "control+option+k",
            lua: "KiwiDesk.show_shortcuts()",
            kind: .navigation,
            label: "Show shortcuts panel"
        )
    }

    // MARK: - Per-space rows (one per tier, shared with top-up)

    /// Tier 1 — ⌃⌥ + digit: focus (go to) a space.
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

    /// Tier 2 — ⌃⌥⇧ + digit: move the window to a space.
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

    /// Tier 3 — ⌃⌥⌘ + digit: move the window and follow it.
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

    /// The per-space digit rows MISSING from `existing` for the
    /// live `spaces` — the additive top-up when a display change
    /// grows the space count past the digits seeded on first run
    /// (#485). Strictly additive: a digit whose combo is already
    /// bound (a seeded default OR a user's custom chord) is left
    /// untouched, so the top-up can never overwrite a binding. The
    /// same position → digit mapping and ten-cap as `bindings`
    /// (`numbered`), so a space past the tenth still ships unbound.
    /// Combo identity is by parsed `KeyCombo`, so an equivalent
    /// hand-authored alias (`ctrl+alt+6`) counts as taken.
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

    /// How many spaces can carry a default digit shortcut: the
    /// number row, `1`…`9` then `0`. Public because it is the
    /// reason the starter setup's own budget stops where it does
    /// — we run out of keys before we run out of spaces — and a
    /// second copy of the number over there would be a restated
    /// constant rather than a derived one.
    public static let digitCapacity = 10

    /// The first ten spaces paired with the digit key each
    /// per-space combo uses: positions 1…9 map to `"1"`…`"9"`, and
    /// the tenth to `"0"` (⌃⌥0 = space 10, the top-row order). Ten
    /// is the hard cap — the number row has no eleventh digit — so
    /// spaces past the tenth ship unbound by default (#466);
    /// they stay bindable in the Keybindings editor.
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
