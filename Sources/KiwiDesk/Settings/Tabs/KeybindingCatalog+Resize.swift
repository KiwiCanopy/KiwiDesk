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
            makeFloating,
        ]
    }

    /// The Make-floating row — step-independent, so unlike
    /// Grow/Shrink it is a fixed command. A named single
    /// authority because the import classifier matches it
    /// directly (it is in no `navigationGroups` group and has
    /// no shape rule); without that entry an imported
    /// `make_floating()` binding demoted to Custom (#4/#91).
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
