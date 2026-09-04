import Foundation

/// Migrates `profile_bindings` from `"2": "Work"` to
/// `"2": {"desktop": 2, "profile": "Work"}` (#1147,
/// `ConfigMigrationRoutingTests`, `ProfileBindingMigrationTests`).
///
/// The value became an object because a binding is now filed
/// under the Desktop's own stamp, and the number it was declared
/// at has to survive beside it — it is what a row is labelled
/// with while its Desktop is away. The decoder is STRICT
/// (AGENTS.md §5), so without this step a gui.json written by any
/// earlier build fails to decode as a UNIT: the user loses their
/// spaces, rules and shortcuts along with the binding.
extension ConfigMigration {
    static let profileBindingsKey = "profile_bindings"
    /// Spelled here rather than derived from `DesktopBinding`: a
    /// historical step must keep emitting the names it was
    /// written to emit, so a LATER rename composes on top.
    static let bindingProfileKey = "profile"
    static let bindingDesktopKey = "desktop"

    /// Rewrites string-valued Desktop bindings as objects.
    @Sendable
    static func migratingProfileBindingStrings(
        _ data: Data
    ) -> Data? {
        let needle = Data("\"\(profileBindingsKey)\"".utf8)
        return surgicallyApplying(
            data,
            gate: { $0.range(of: needle) != nil },
            rewriting: bindingsExpanded,
            // No textual edit: the rewrite replaces a scalar with
            // an object rather than renaming a key, so there is
            // no edit a regex could make that the tree walk would
            // not have to verify line by line anyway.
            editing: { _ in nil }
        )
    }

    /// Tree walker expanding a string-valued `profile_bindings`
    /// map at any depth — a `SetupBundle` carries `config`
    /// inline, so the node is nested there.
    static func bindingsExpanded(_ node: Any) -> (Any, Bool) {
        if let dict = node as? [String: Any] {
            var out: [String: Any] = [:]
            var changed = false
            for (key, value) in dict {
                if key == profileBindingsKey,
                    let expanded = expandedBindings(value)
                {
                    out[key] = expanded
                    changed = true
                    continue
                }
                let (child, childChanged) = bindingsExpanded(value)
                out[key] = child
                changed = changed || childChanged
            }
            return (out, changed)
        }
        if let array = node as? [Any] {
            var out: [Any] = []
            var changed = false
            for value in array {
                let (child, childChanged) = bindingsExpanded(value)
                out.append(child)
                changed = changed || childChanged
            }
            return (out, changed)
        }
        return (node, false)
    }

    /// The map's own expansion, or nil when nothing in it is a
    /// bare string — a map already in the new shape, or one this
    /// step has already run over, is left untouched so a second
    /// pass rewrites nothing.
    private static func expandedBindings(_ value: Any) -> Any? {
        guard let map = value as? [String: Any],
            map.values.contains(where: { $0 is String })
        else { return nil }
        var out: [String: Any] = [:]
        for (key, entry) in map {
            guard let profile = entry as? String else {
                out[key] = entry
                continue
            }
            // The key WAS the Mission Control number, so it is
            // also the projection. A key that is not a number
            // was already unreadable to the old decoder, which
            // dropped it; drop it here too rather than inventing
            // a Desktop for it.
            guard let number = Int(key) else { continue }
            out[key] = [
                bindingProfileKey: profile,
                bindingDesktopKey: number,
            ]
        }
        return out
    }
}
