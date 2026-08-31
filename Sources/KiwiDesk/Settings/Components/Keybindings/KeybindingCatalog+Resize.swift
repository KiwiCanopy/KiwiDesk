import KiwiDeskCore

/// Window size and float preset commands (#56, #58).
extension KeybindingCatalog {
    /// Window-size and float presets for shortcuts view (#56, #58).
    static func resizeAndFloat(step: Int) -> [NavCommand] {
        ResizeRow.allCases.map { resizeRow($0, step: step) }
            + [
                toggleFloating,
                toggleSticky,
                toggleDisplaySticky,
            ]
    }

    /// Step-independent floating and sticky commands — THE one
    /// copy (review 2026-08-10): the import classifier's label map
    /// and the banner's roster both consume this list; as two
    /// hand-mirrors, a drifted command classified with an English
    /// label the banner interpolated untranslated.
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

    /// Resize row family identifiers (#678 Phase 3). Named, not
    /// positional: indexing into `resizeAndFloat` would silently
    /// re-point a family at its neighbour on any row insertion.
    enum ResizeRow: CaseIterable {
        case growWidth
        case shrinkWidth
        case growHeight
        case shrinkHeight
    }

    /// Constructs single-axis resize command (#4).
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

    /// Toggle floating window command (#221).
    static let toggleFloating = NavCommand(
        label: "Toggle floating",
        lua: "KiwiDesk.toggle_floating()",
        displayLabel: {
            L("keybinding.toggle_floating", "Toggle floating")
        }
    )

    /// Toggle sticky across all spaces (#221, #414).
    static let toggleSticky = NavCommand(
        label: "Toggle sticky",
        lua: "KiwiDesk.toggle_sticky()",
        displayLabel: {
            L(
                "keybinding.toggle_sticky",
                "Toggle sticky everywhere"
            )
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

    /// Toggle sticky on current display (#445).
    static let toggleDisplaySticky = NavCommand(
        label: "Toggle display sticky",
        lua: "KiwiDesk.toggle_display_sticky()",
        displayLabel: {
            L(
                "keybinding.toggle_display_sticky",
                "Toggle sticky on this screen"
            )
        },
        help: {
            L(
                "keybinding.toggle_display_sticky.help",
                "Keeps this window visible on every Space of the "
                    + "screen it lives on. Moving it to a Space on "
                    + "another screen re-homes it there. Turn a "
                    + "sticky window fully global with “%1$@”.",
                L(
                    "keybinding.toggle_sticky",
                    "Toggle sticky everywhere"
                )
            )
        }
    )

    /// Import classification anchor for make sticky (#4, #91).
    static let makeSticky = NavCommand(
        label: "Make sticky",
        lua: "KiwiDesk.make_sticky()",
        displayLabel: {
            L(
                "keybinding.make_sticky",
                "Make sticky everywhere"
            )
        }
    )

    static let makeDisplaySticky = NavCommand(
        label: "Make display sticky",
        lua: "KiwiDesk.make_display_sticky()",
        displayLabel: {
            L(
                "keybinding.make_display_sticky",
                "Make sticky on this screen"
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

    /// Import classification anchor for make floating (#4, #91, #221).
    static let makeFloating = NavCommand(
        label: "Make floating",
        lua: "KiwiDesk.make_floating()",
        displayLabel: {
            L("keybinding.make_floating", "Make floating")
        }
    )

    /// Parses single-axis resize magnitude and label from Lua
    /// (#56, #58). A SHAPE match, not byte-for-byte: a config
    /// whose step differs from the current one still lands in
    /// Size & float, and its magnitude reads back into
    /// `resize.step`.
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
