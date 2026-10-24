import Foundation

/// Retires the per-layout `wrap_focus` switches (#2493,
/// `WrapFocusMigrationTests`, `ConfigMigrationRoutingTests`): one
/// `focus_wrap` setting answers every layout, and every file crosses
/// to its default, All screens, whatever the switches stored (owner
/// ruling 2026-10-23), so the key drops from `layout.scroll`,
/// `layout.monocle` and `layout.track`. Changes no value — no params
/// type declares the key — and ends the file in the new shape, as
/// `overflow_style`'s step did (#2235). Unscoped by parent: no other
/// setting spells the key.
extension ConfigMigration {
    /// Spelled rather than derived: a historical step keeps naming
    /// what it was written to name.
    static let retiredWrapFocusKey = "wrap_focus"

    @Sendable
    static func migratingRetiredWrapFocus(_ data: Data) -> Data? {
        let needle = Data("\"\(retiredWrapFocusKey)\"".utf8)
        return surgicallyApplying(
            data,
            gate: { $0.range(of: needle) != nil },
            rewriting: withoutWrapFocus,
            editing: surgicallyDroppedWrapFocus
        )
    }

    /// Deletes every Bool-valued `wrap_focus` entry from the raw
    /// text, keeping the file's formatting.
    static func surgicallyDroppedWrapFocus(_ text: String) -> Data? {
        let entry = "\"\(retiredWrapFocusKey)\"\\s*:\\s*(?:true|false)"
        var out = text
        for pattern in [
            entry + "\\s*,\\s*", "\\s*,\\s*" + entry, entry,
        ] {
            out = out.replacingOccurrences(
                of: pattern,
                with: "",
                options: .regularExpression
            )
        }
        return out == text ? nil : out.data(using: .utf8)
    }

    /// Tree walker dropping the key from every object at any depth.
    static func withoutWrapFocus(_ node: Any) -> (Any, Bool) {
        if let dict = node as? [String: Any] {
            var out: [String: Any] = [:]
            var changed = dict[retiredWrapFocusKey] != nil
            for (key, value) in dict where key != retiredWrapFocusKey {
                let (child, childChanged) = withoutWrapFocus(value)
                out[key] = child
                changed = changed || childChanged
            }
            return (out, changed)
        }
        if let array = node as? [Any] {
            var out: [Any] = []
            var changed = false
            for value in array {
                let (child, childChanged) = withoutWrapFocus(value)
                out.append(child)
                changed = changed || childChanged
            }
            return (out, changed)
        }
        return (node, false)
    }
}
