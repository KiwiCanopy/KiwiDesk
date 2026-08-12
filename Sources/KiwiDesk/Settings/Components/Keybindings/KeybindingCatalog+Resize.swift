import KiwiDeskCore

/// The Size & float presets, split out of `KeybindingCatalog`
/// for file size (AGENTS.md §2): the per-axis Grow/Shrink rows
/// (#56), the Make-floating row, and `resizeShape` — the import
/// classifier's inverse of the resize authoring.
extension KeybindingCatalog {
    /// Window-size and float presets (Size & float, §3.6.1).
    /// The four Grow/Shrink rows nudge the layout by `step`
    /// points — the configurable global `resize.step` (#58),
    /// passed in by the caller from live settings — on either
    /// axis (true 2-axis resize, #56): width rows resize on
    /// `"x"`, height rows on `"y"`. Resize is a no-op in
    /// monocle/grid/floating; the section caption states this
    /// and the docs echo it.
    static func resizeAndFloat(step: Int) -> [NavCommand] {
        ResizeRow.allCases.map { resizeRow($0, step: step) }
            + [
                toggleFloating,
                toggleSticky,
                toggleDisplaySticky,
            ]
    }

    /// The step-independent float/sticky bracket plus the
    /// shortcuts-panel row — THE one copy (review 2026-08-10):
    /// the import classifier's label map and the banner's
    /// `localizedLabel` roster both consume this list, so a
    /// command recognisable by one is resolvable by the other.
    /// It shipped as two hand-mirrors first, and the drift is
    /// user-visible: a command in the classifier's copy alone
    /// classifies with an English label the banner then
    /// interpolates untranslated.
    static let stepFreeCommands: [NavCommand] = [
        toggleFloating,
        makeFloating,
        toggleSticky,
        toggleDisplaySticky,
        makeSticky,
        makeDisplaySticky,
        makeUnsticky,
        showShortcuts,
        openSettings,
    ]

    /// The four resize rows, one census family each (#678
    /// Phase 3). Named rather than positional: the Shortcuts
    /// area renders per family, and addressing these by index
    /// into `resizeAndFloat` would silently re-point a family at
    /// its neighbour the moment a row was inserted.
    enum ResizeRow: CaseIterable {
        case growWidth
        case shrinkWidth
        case growHeight
        case shrinkHeight
    }

    /// One resize row, step baked into its Lua. The single
    /// authority for these four commands — `resizeAndFloat`
    /// composes from it rather than repeating them, so the row
    /// the GUI writes and the row the import classifier matches
    /// stay byte-identical (#4).
    static func resizeRow(
        _ row: ResizeRow,
        step: Int
    ) -> NavCommand {
        switch row {
        case .growWidth:
            return NavCommand(
                label: "Grow width",
                lua: "KiwiDesk.resize(\"x\", \(step))",
                displayLabel: {
                    L("keybinding.grow_width", "Grow width")
                }
            )
        case .shrinkWidth:
            return NavCommand(
                label: "Shrink width",
                lua: "KiwiDesk.resize(\"x\", -\(step))",
                displayLabel: {
                    L("keybinding.shrink_width", "Shrink width")
                }
            )
        case .growHeight:
            return NavCommand(
                label: "Grow height",
                lua: "KiwiDesk.resize(\"y\", \(step))",
                displayLabel: {
                    L("keybinding.grow_height", "Grow height")
                }
            )
        case .shrinkHeight:
            return NavCommand(
                label: "Shrink height",
                lua: "KiwiDesk.resize(\"y\", -\(step))",
                displayLabel: {
                    L(
                        "keybinding.shrink_height",
                        "Shrink height"
                    )
                }
            )
        }
    }

    /// The Toggle-floating row — the one float verb offered as a
    /// bindable preset (#221): flip the focused window between
    /// floating and tiled. The explicit `make_floating` /
    /// `make_tiled` / `make_auto` verbs stay Lua/CLI-only (the
    /// power-user escape hatch), so only this appears in the GUI
    /// list. Step-independent, so a fixed command like the old
    /// Make-floating row it replaces.
    static let toggleFloating = NavCommand(
        label: "Toggle floating",
        lua: "KiwiDesk.toggle_floating()",
        displayLabel: {
            L("keybinding.toggle_floating", "Toggle floating")
        }
    )

    /// The Toggle-sticky row (#414) — the one sticky verb
    /// offered as a bindable preset (the #221 pattern): keep
    /// the window on every space, or stop. `make_sticky` /
    /// `make_unsticky` stay Lua/CLI-only, recognized below.
    static let toggleSticky = NavCommand(
        label: "Toggle sticky",
        lua: "KiwiDesk.toggle_sticky()",
        displayLabel: {
            L("keybinding.toggle_sticky", "Toggle sticky")
        },
        help: {
            L(
                "keybinding.toggle_sticky.help",
                "Keeps this window visible on every Space. A "
                    + "tiled sticky window can be rearranged only "
                    + "on its home Space — elsewhere, its position "
                    + "follows automatically. A floating sticky "
                    + "window isn't affected — it moves freely "
                    + "everywhere."
            )
        }
    )

    /// The Toggle-display-sticky row (#445) — the coarse-to-fine
    /// peer of Toggle sticky: keep the window on every space of
    /// THIS monitor only, or stop. `make_display_sticky` /
    /// `make_unsticky` stay Lua/CLI-only, recognized below.
    static let toggleDisplaySticky = NavCommand(
        label: "Toggle display sticky",
        lua: "KiwiDesk.toggle_display_sticky()",
        displayLabel: {
            L(
                "keybinding.toggle_display_sticky",
                "Toggle display sticky"
            )
        },
        help: {
            L(
                "keybinding.toggle_display_sticky.help",
                "Keeps this window visible on every Space of the "
                    + "monitor it lives on. Moving it to a Space on "
                    + "another monitor re-homes it there. Turn a "
                    + "sticky window fully global with Toggle sticky."
            )
        }
    )

    /// Classification-only anchors (#4/#91) for hand-written
    /// sticky verbs, mirroring `makeFloating` below: imported
    /// bindings land in Size & float with proper labels
    /// instead of demoting to Custom.
    static let makeSticky = NavCommand(
        label: "Make sticky",
        lua: "KiwiDesk.make_sticky()",
        displayLabel: {
            L("keybinding.make_sticky", "Make sticky")
        }
    )

    static let makeDisplaySticky = NavCommand(
        label: "Make display sticky",
        lua: "KiwiDesk.make_display_sticky()",
        displayLabel: {
            L(
                "keybinding.make_display_sticky",
                "Make display sticky"
            )
        }
    )

    static let makeUnsticky = NavCommand(
        label: "Make unsticky",
        lua: "KiwiDesk.make_unsticky()",
        displayLabel: {
            L("keybinding.make_unsticky", "Make unsticky")
        }
    )

    /// Classification-only anchor for a hand-written
    /// `make_floating()` (#4/#91): not offered as a bindable
    /// preset anymore (#221), but the import classifier still
    /// matches it directly so an imported binding lands in Size &
    /// Float with its proper label instead of demoting to Custom.
    static let makeFloating = NavCommand(
        label: "Make floating",
        lua: "KiwiDesk.make_floating()",
        displayLabel: {
            L("keybinding.make_floating", "Make floating")
        }
    )

    /// The Grow/Shrink magnitude inside a `resize("x"|"y", ±N)`
    /// row of ANY step, plus its canonical label — the inverse of
    /// `resizeAndFloat`'s authoring, used by import classification
    /// (#58, both axes since #56). A shape match (not
    /// byte-for-byte) so a config whose step differs from the
    /// current one still lands in Size & float, and its magnitude
    /// is read back into `resize.step`. Nil unless `lua` is
    /// exactly a single-axis resize with a non-zero integer delta.
    static func resizeShape(
        from lua: String
    ) -> (label: String, step: Int)? {
        let suffix = ")"
        let axes = [
            ("KiwiDesk.resize(\"x\", ", "width"),
            ("KiwiDesk.resize(\"y\", ", "height"),
        ]
        for (prefix, dimension) in axes {
            guard lua.hasPrefix(prefix), lua.hasSuffix(suffix)
            else { continue }
            let inner = lua.dropFirst(prefix.count)
                .dropLast(suffix.count)
            guard let value = Int(inner), value != 0 else {
                return nil
            }
            let verb = value < 0 ? "Shrink" : "Grow"
            return ("\(verb) \(dimension)", abs(value))
        }
        return nil
    }
}
