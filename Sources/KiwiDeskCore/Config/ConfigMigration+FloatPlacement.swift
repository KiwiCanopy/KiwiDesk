import Foundation

/// Retires `float_nudge` for `float_placement` (#1674,
/// `ConfigMigrationRoutingTests`, `FloatPlacementMigrationTests`).
///
/// A stored `false` was a choice — the default was on — and
/// becomes `"keep"`. A stored `true` is dropped rather than
/// carried: the encoder wrote the key into every file under the
/// old default, so it records a save, not a choice (the #1255
/// precedent), and the new default `"center"` lands on it.
extension ConfigMigration {
    /// Spelled rather than derived: a historical step keeps
    /// naming what it was written to name.
    static let retiredFloatNudgeKey = "float_nudge"
    static let floatPlacementKey = "float_placement"
    static let floatPlacementKeep = "keep"

    @Sendable
    static func migratingRetiredFloatNudge(_ data: Data) -> Data? {
        let needle = Data("\"\(retiredFloatNudgeKey)\"".utf8)
        return surgicallyApplying(
            data,
            gate: { $0.range(of: needle) != nil },
            rewriting: withoutFloatNudge,
            editing: surgicallyRetiredFloatNudge
        )
    }

    /// The textual edit: `false` renamed onto the new key, `true`
    /// deleted with its comma. Stands down where the new key is
    /// already present — a textual edit cannot see a sibling, so
    /// the walk handles a node carrying both.
    static func surgicallyRetiredFloatNudge(_ text: String) -> Data? {
        guard !text.contains("\"\(floatPlacementKey)\"")
        else { return nil }
        let key = "\"\(retiredFloatNudgeKey)\""
        var out = text.replacingOccurrences(
            of: key + "(\\s*:\\s*)false",
            with: "\"\(floatPlacementKey)\"$1\"\(floatPlacementKeep)\"",
            options: .regularExpression
        )
        let entry = key + "\\s*:\\s*true"
        for pattern in [entry + "\\s*,\\s*", "\\s*,\\s*" + entry] {
            out = out.replacingOccurrences(
                of: pattern,
                with: "",
                options: .regularExpression
            )
        }
        return out == text ? nil : out.data(using: .utf8)
    }

    /// Tree walker over every object carrying the retired key;
    /// an explicit `float_placement` beside it wins.
    static func withoutFloatNudge(_ node: Any) -> (Any, Bool) {
        if let dict = node as? [String: Any] {
            var out: [String: Any] = [:]
            var changed = false
            for (key, value) in dict {
                let (child, childChanged) = withoutFloatNudge(value)
                out[key] = child
                changed = changed || childChanged
            }
            if let nudge = out.removeValue(
                forKey: retiredFloatNudgeKey
            ) {
                if nudge as? Bool == false,
                    out[floatPlacementKey] == nil
                {
                    out[floatPlacementKey] = floatPlacementKeep
                }
                changed = true
            }
            return (out, changed)
        }
        if let array = node as? [Any] {
            var out: [Any] = []
            var changed = false
            for value in array {
                let (child, childChanged) = withoutFloatNudge(value)
                out.append(child)
                changed = changed || childChanged
            }
            return (out, changed)
        }
        return (node, false)
    }
}
