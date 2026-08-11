import AppKit
import KiwiDeskCore

/// The catalog backing the keybindings tab: navigation presets
/// and installed applications. Known macOS shortcuts used for
/// conflict detection live in Core's `SystemShortcuts`.
enum KeybindingCatalog {
    // dir is the Lua argument; phrase is the positional English
    // wording used in the canonical `label` ("above"/"below"
    // read better than "up"/"down").
    private static let directions = [
        ("left", "to the left"), ("down", "below"),
        ("up", "above"), ("right", "to the right"),
    ]

    /// The translated phrase for a direction's Lua argument.
    /// A literal `L(...)` per case (not a dynamic key lookup)
    /// so `scripts/extract-keys` can enumerate it — the
    /// extractor only recognizes string-literal key/English
    /// arguments (`docs/translating.md` § Extraction
    /// limitations).
    @MainActor private static func directionPhrase(
        _ dir: String
    ) -> String {
        switch dir {
        case "left":
            return L("keybinding.dir.left", "to the left")
        case "down":
            return L("keybinding.dir.below", "below")
        case "up":
            return L("keybinding.dir.above", "above")
        case "right":
            return L("keybinding.dir.right", "to the right")
        default:
            return dir
        }
    }

    /// The four directional focus rows (#68 §3.6.1 Focus).
    static let focusDirections: [NavCommand] = directions.map {
        dir,
        phrase in
        NavCommand(
            label: "Focus window \(phrase)",
            lua: "KiwiDesk.focus(\"\(dir)\")",
            displayLabel: {
                L(
                    "keybinding.focus_dir",
                    "Focus window %1$@",
                    directionPhrase(dir)
                )
            }
        )
    }

    /// One "Go to Space …" row per defined space. The space
    /// name is user data (never translated), passed as a
    /// positional arg into the translated sentence.
    static func goToSpace(
        _ spaces: [SpaceID],
        icons: [SpaceID: String] = [:]
    ) -> [NavCommand] {
        spaces.map { space in
            NavCommand(
                label: "Go to Space \(space.raw)",
                lua: "KiwiDesk.focus_space"
                    + "(\(spaceArg(space)))",
                icon: icons[space],
                displayLabel: {
                    L(
                        "keybinding.go_to_space",
                        "Go to Space %1$@",
                        space.raw
                    )
                }
            )
        }
    }

    /// The four directional swap rows (Move windows).
    static let swapDirections: [NavCommand] = directions.map {
        dir,
        phrase in
        NavCommand(
            label: "Swap with window \(phrase)",
            lua: "KiwiDesk.swap(\"\(dir)\")",
            displayLabel: {
                L(
                    "keybinding.swap_dir",
                    "Swap with window %1$@",
                    directionPhrase(dir)
                )
            }
        )
    }

    /// The track verbs speak prev/next, not compass directions
    /// (#185 review): they act on the 1D track sequence, so
    /// two rows replace four (no per-axis inert pair, and a
    /// binding survives an axis flip). prev = the track toward
    /// the sequence start — left for columns, top for rows;
    /// next toward the end — right/bottom.
    private static let sequenceSteps = [
        ("prev", "previous"), ("next", "next"),
    ]

    /// The translated phrase for a sequence step's Lua
    /// argument (the `directionPhrase` twin). i18n seam: the
    /// one phrase interpolates into BOTH sentence frames
    /// (move + swap), which works for en/de but cannot carry
    /// per-frame case/gender inflection — if a 1.0 language
    /// (#95) needs it, split into per-frame keys then.
    @MainActor private static func sequencePhrase(
        _ step: String
    ) -> String {
        switch step {
        case "prev":
            return L("keybinding.seq.prev", "previous")
        case "next":
            return L("keybinding.seq.next", "next")
        default:
            return step
        }
    }

    /// The two move-to-track rows (#128, prev/next). Labels
    /// name the actor — the window moves, not the focus.
    static let moveToTrackRows: [NavCommand] =
        sequenceSteps.map { step, phrase in
            NavCommand(
                label: "Move window to \(phrase) track",
                lua: "KiwiDesk.move_to_track(\"\(step)\")",
                displayLabel: {
                    L(
                        "keybinding.move_window_to_track",
                        "Move window to %1$@ track",
                        sequencePhrase(step)
                    )
                }
            )
        }

    /// The two whole-track swap rows (#182, prev/next).
    /// Always rendered like `moveToTrackRows` (the gate was
    /// dropped in #188); only relevant in the track layout.
    static let trackSwapRows: [NavCommand] =
        sequenceSteps.map { step, phrase in
            NavCommand(
                label: "Swap with \(phrase) track",
                lua: "track.swap(\"\(step)\")",
                displayLabel: {
                    L(
                        "keybinding.swap_with_track",
                        "Swap with %1$@ track",
                        sequencePhrase(step)
                    )
                }
            )
        }

    /// The per-space "Move to …" / "… & follow" row pairs,
    /// interleaved per space — the order the import classifier
    /// and the old flat group both read.
    ///
    /// Composed from the two half-builders below rather than
    /// repeating their commands: "Move to space" and "Move to
    /// space & follow" are two census families (#678 Phase 3),
    /// so the Shortcuts area renders each half on its own, and a
    /// second copy of either Lua here would be the byte-for-byte
    /// drift that silently demotes an import to Custom (#4).
    static func moveToSpace(
        _ spaces: [SpaceID],
        icons: [SpaceID: String] = [:]
    ) -> [NavCommand] {
        zip(
            moveToSpaceRows(spaces, icons: icons),
            moveToSpaceFollowRows(spaces, icons: icons)
        )
        .flatMap { [$0, $1] }
    }

    /// One "Move to Space …" row per space. The space name is
    /// user data, passed as a positional arg.
    static func moveToSpaceRows(
        _ spaces: [SpaceID],
        icons: [SpaceID: String] = [:]
    ) -> [NavCommand] {
        spaces.map { space in
            NavCommand(
                label: "Move to Space \(space.raw)",
                lua:
                    "KiwiDesk.move_to_space(\(spaceArg(space)))",
                icon: icons[space],
                displayLabel: {
                    L(
                        "keybinding.move_to_space",
                        "Move to Space %1$@",
                        space.raw
                    )
                }
            )
        }
    }

    /// One "Move to Space … & follow" row per space.
    static func moveToSpaceFollowRows(
        _ spaces: [SpaceID],
        icons: [SpaceID: String] = [:]
    ) -> [NavCommand] {
        spaces.map { space in
            NavCommand(
                label: "Move to Space \(space.raw) & follow",
                lua: "KiwiDesk."
                    + "move_to_space_and_follow"
                    + "(\(spaceArg(space)))",
                icon: icons[space],
                displayLabel: {
                    L(
                        "keybinding.move_to_space_follow",
                        "Move to Space %1$@ & follow",
                        space.raw
                    )
                }
            )
        }
    }

    /// Navigation grouped for the import classifier (#4): the
    /// commands the sections render, so a recovered row matches
    /// byte-for-byte. Grow/Shrink is deliberately absent — its
    /// magnitude is configurable (#58), so import matches it by
    /// *shape* via `resizeShape(from:)`, not from this map.
    static func navigationGroups(
        spaces: [SpaceID]
    ) -> [NavGroup] {
        [
            NavGroup(
                title: "Focus",
                commands: focusDirections + goToSpace(spaces)
            ),
            NavGroup(
                title: "Window Management",
                commands: swapDirections
                    + moveToTrackRows
                    + trackSwapRows
                    + moveToSpace(spaces)
            ),
        ]
    }

    // Size & float presets (resizeAndFloat, makeFloating,
    // resizeShape) live in `KeybindingCatalog+Resize.swift`.

    /// A space id as a quoted, escaped Lua string argument.
    static func spaceArg(_ space: SpaceID) -> String {
        quote(space.raw)
    }

    /// A quoted, escaped Lua string literal. Delegates to the
    /// canonical `SpaceLuaArg.quote` so the form a space rename
    /// rewrites always matches what the catalog authored (#13).
    static func quote(_ raw: String) -> String {
        SpaceLuaArg.quote(raw)
    }

    /// The bindable "open the shortcuts reference panel" row
    /// (#330): a GUI action verb (`KiwiDesk.show_shortcuts()`).
    /// Seeded to **⌃⌥K** by default (#602) — reachable from the
    /// keyboard out of the box — but editable or clearable per
    /// layer like any default. The Lua comes from
    /// `ShortcutsOpenBinding` so the row, the classifier, and the
    /// quick-menu combo all speak of one binding.
    static let showShortcuts = NavCommand(
        label: "Show shortcuts panel",
        lua: ShortcutsOpenBinding.lua,
        displayLabel: {
            L("keybinding.show_shortcuts", "Show shortcuts panel")
        }
    )

    /// The bindable "Open Settings" row (#678 item 18): a GUI
    /// action verb (`KiwiDesk.show_settings()`), deliberately
    /// UNBOUND by default — Settings is not a prerequisite, so
    /// no default chord is spent on it. The catalog row is the
    /// one production copy of the Lua body;
    /// `ShowSettingsVerbTests` pins it to the Core verb.
    static let openSettings = NavCommand(
        label: "Open Settings",
        lua: "KiwiDesk.show_settings()",
        displayLabel: {
            L("keybinding.open_settings", "Open Settings")
        }
    )
}
