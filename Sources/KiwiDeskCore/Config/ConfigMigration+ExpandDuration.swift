import Foundation

/// Migrates `animations.on_shelf` to `on_expand` and
/// `animations.shelf_duration` to `expand_duration` (owner ruling,
/// 2026-10-21, `ExpandDurationMigrationTests`,
/// `ExpandDurationMigrationRoutingTests`): the shelf's glide became
/// its expand, beside the reveal's own duration. Without the step
/// the failure is SILENT — `AnimationSettings` decodes both with
/// `decodeIfPresent ?? default`, dropping a tuned value.
///
/// Two families of key, both renamed by KEY at any depth: the
/// field inside a profile's `animations` object, and the look path
/// a look's `style` map is keyed by (`LookKeys.motion`) — in a
/// profile's own look, `gui.json`'s shared look, `looks.json` and a
/// bundle's inline copies of all three.
extension ConfigMigration {
    /// Spelled rather than derived, as #1020's: a historical step
    /// keeps emitting the names it was written to emit.
    static let expandRenames: [(retired: String, target: String)] = [
        ("on_shelf", "on_expand"),
        ("shelf_duration", "expand_duration"),
        ("animations.on_shelf", "animations.on_expand"),
        ("animations.shelf_duration", "animations.expand_duration"),
    ]

    @Sendable
    static func migratingShelfGlideOntoExpand(_ data: Data) -> Data? {
        let needles = expandRenames.map {
            Data("\"\($0.retired)\"".utf8)
        }
        return surgicallyApplying(
            data,
            gate: { data in needles.contains { data.range(of: $0) != nil } },
            rewriting: { root in
                expandRenames.reduce((root, false)) { state, rename in
                    let (node, changed) = renamingKey(
                        rename.retired,
                        to: rename.target,
                        in: state.0
                    )
                    return (node, state.1 || changed)
                }
            },
            editing: { text in
                var current = text
                var edited = false
                for rename in expandRenames {
                    guard current.contains("\"\(rename.retired)\"") else {
                        continue
                    }
                    guard
                        let next = surgicallyRenamingKey(
                            rename.retired,
                            to: rename.target,
                            in: current
                        ),
                        let string = String(data: next, encoding: .utf8)
                    else { return nil }
                    current = string
                    edited = true
                }
                return edited ? current.data(using: .utf8) : nil
            }
        )
    }
}
