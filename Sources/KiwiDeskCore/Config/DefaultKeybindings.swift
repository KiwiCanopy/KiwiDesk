import Foundation

/// The first-run starter shortcuts (#91): the set seeded into
/// the base `default` mode when no binding exists anywhere —
/// a fresh install, or a config whose Lua declares none — so a
/// new user can focus, move, and navigate windows immediately.
///
/// The Lua and canonical labels mirror what
/// `KeybindingCatalog` (GUI target) authors for the same
/// spaces and resize step — byte-for-byte, or the import
/// classifier would demote the rows to Custom (#4). That
/// mirror is guarded by `DefaultSeedCatalogParityTests`
/// (GUI tests), which iterates every seeded row and matches
/// it against the catalog's output.
///
/// Per-space rows are position-based (`option+1` targets the
/// FIRST space in display order, whatever its name), generated
/// only for the spaces that exist at seed time and capped at
/// nine — so no dead row targeting a nonexistent space is ever
/// authored (#91).
public enum DefaultKeybindings {
    /// Key ↔ direction ↔ canonical label phrase, in the
    /// catalog's order (left, down, up, right — vim h/j/k/l).
    private static let directions = [
        ("h", "left", "to the left"),
        ("j", "down", "below"),
        ("k", "up", "above"),
        ("l", "right", "to the right"),
    ]

    /// The starter rows for the base `default` mode.
    public static func bindings(
        spaces: [SpaceID],
        resizeStep: Int
    ) -> [KeyBinding] {
        var rows: [KeyBinding] = []
        for (key, dir, phrase) in directions {
            rows.append(
                KeyBinding(
                    combo: "option+\(key)",
                    lua: "KiwiDesk.focus(\"\(dir)\")",
                    kind: .navigation,
                    label: "Focus window \(phrase)"
                )
            )
        }
        for (offset, space) in numbered(spaces) {
            rows.append(
                KeyBinding(
                    combo: "option+\(offset)",
                    lua: "KiwiDesk.focus_space"
                        + "(\(SpaceLuaArg.quote(space.raw)))",
                    kind: .navigation,
                    label: "Go to Space \(space.raw)"
                )
            )
        }
        for (key, dir, phrase) in directions {
            rows.append(
                KeyBinding(
                    combo: "option+shift+\(key)",
                    lua: "KiwiDesk.swap(\"\(dir)\")",
                    kind: .navigation,
                    label: "Swap with window \(phrase)"
                )
            )
        }
        for (offset, space) in numbered(spaces) {
            rows.append(
                KeyBinding(
                    combo: "option+shift+\(offset)",
                    lua: "KiwiDesk.move_to_space"
                        + "(\(SpaceLuaArg.quote(space.raw)))",
                    kind: .navigation,
                    label: "Move to Space \(space.raw)"
                )
            )
        }
        rows.append(
            KeyBinding(
                combo: "option+minus",
                lua: "KiwiDesk.resize(\"x\", -\(resizeStep))",
                kind: .navigation,
                label: "Shrink width"
            )
        )
        rows.append(
            KeyBinding(
                combo: "option+equal",
                lua: "KiwiDesk.resize(\"x\", \(resizeStep))",
                kind: .navigation,
                label: "Grow width"
            )
        )
        rows.append(
            KeyBinding(
                combo: "option+shift+minus",
                lua: "KiwiDesk.resize(\"y\", -\(resizeStep))",
                kind: .navigation,
                label: "Shrink height"
            )
        )
        rows.append(
            KeyBinding(
                combo: "option+shift+equal",
                lua: "KiwiDesk.resize(\"y\", \(resizeStep))",
                kind: .navigation,
                label: "Grow height"
            )
        )
        rows.append(
            KeyBinding(
                combo: "option+t",
                lua: "KiwiDesk.make_floating()",
                kind: .navigation,
                label: "Make floating"
            )
        )
        return rows
    }

    /// The first nine spaces paired with their 1-based display
    /// position — the digit each per-space combo uses.
    private static func numbered(
        _ spaces: [SpaceID]
    ) -> [(Int, SpaceID)] {
        spaces.prefix(9).enumerated().map { ($0 + 1, $1) }
    }
}
