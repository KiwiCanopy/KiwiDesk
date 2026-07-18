import KiwiDeskCore

/// The Size & Float presets, split out of `KeybindingCatalog`
/// for file size (AGENTS.md §2): the per-axis Grow/Shrink rows
/// (#56), the Make-floating row, and `resizeShape` — the import
/// classifier's inverse of the resize authoring.
extension KeybindingCatalog {
    /// Window-size and float presets (Size & Float, §3.6.1).
    /// The four Grow/Shrink rows nudge the layout by `step`
    /// points — the configurable global `resize.step` (#58),
    /// passed in by the caller from live settings — on either
    /// axis (true 2-axis resize, #56): width rows resize on
    /// `"x"`, height rows on `"y"`. Resize is a no-op in
    /// monocle/grid/floating; the section caption states this
    /// and the docs echo it.
    static func resizeAndFloat(step: Int) -> [NavCommand] {
        [
            NavCommand(
                label: "Grow width",
                lua: "KiwiDesk.resize(\"x\", \(step))",
                displayLabel: {
                    L("keybinding.grow_width", "Grow width")
                }
            ),
            NavCommand(
                label: "Shrink width",
                lua: "KiwiDesk.resize(\"x\", -\(step))",
                displayLabel: {
                    L("keybinding.shrink_width", "Shrink width")
                }
            ),
            NavCommand(
                label: "Grow height",
                lua: "KiwiDesk.resize(\"y\", \(step))",
                displayLabel: {
                    L("keybinding.grow_height", "Grow height")
                }
            ),
            NavCommand(
                label: "Shrink height",
                lua: "KiwiDesk.resize(\"y\", -\(step))",
                displayLabel: {
                    L(
                        "keybinding.shrink_height",
                        "Shrink height"
                    )
                }
            ),
            toggleFloating,
        ]
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
    /// current one still lands in Size & Float, and its magnitude
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
