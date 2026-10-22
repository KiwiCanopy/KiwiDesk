import Foundation

/// Retires `overflow_style` (#2235, `OverflowStyleMigrationTests`,
/// `ConfigMigrationRoutingTests`): a Stack zone or Track track
/// scrolls its overflow, so the stored key drops from
/// `layout.stack`, `layout.track` and each Space's override under
/// them. Changes no value — neither params type declares the key
/// — and ends the file in the new shape, as `app_bar.content`'s
/// step did (#1528). Unscoped by parent: no other setting spells
/// the key, where `content` needed its parent named.
extension ConfigMigration {
    /// Spelled rather than derived: a historical step keeps
    /// naming what it was written to name.
    static let retiredOverflowStyleKey = "overflow_style"

    @Sendable
    static func migratingRetiredOverflowStyle(_ data: Data) -> Data? {
        let needle = Data("\"\(retiredOverflowStyleKey)\"".utf8)
        return surgicallyApplying(
            data,
            gate: { $0.range(of: needle) != nil },
            rewriting: withoutOverflowStyle,
            editing: surgicallyDroppedOverflowStyle
        )
    }

    /// Deletes every string-valued `overflow_style` entry from the
    /// raw text, keeping the file's formatting and its Doubles.
    static func surgicallyDroppedOverflowStyle(_ text: String) -> Data? {
        let entry =
            "\"\(retiredOverflowStyleKey)\"\\s*:\\s*\"(?:[^\"\\\\]|\\\\.)*\""
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

    /// Tree walker dropping the key from every object at any
    /// depth.
    static func withoutOverflowStyle(_ node: Any) -> (Any, Bool) {
        if let dict = node as? [String: Any] {
            var out: [String: Any] = [:]
            var changed = dict[retiredOverflowStyleKey] != nil
            for (key, value) in dict where key != retiredOverflowStyleKey {
                let (child, childChanged) = withoutOverflowStyle(value)
                out[key] = child
                changed = changed || childChanged
            }
            return (out, changed)
        }
        if let array = node as? [Any] {
            var out: [Any] = []
            var changed = false
            for value in array {
                let (child, childChanged) = withoutOverflowStyle(value)
                out.append(child)
                changed = changed || childChanged
            }
            return (out, changed)
        }
        return (node, false)
    }
}
