import Foundation

/// Retires `app_bar.content` (#1528 item 13,
/// `AppBarContentMigrationTests`, `ConfigMigrationRoutingTests`):
/// the App Bar always draws icon and title, so the stored key
/// drops from the global `app_bar` and from each layout's
/// `app_bar` override. One crossing, whatever the value — it
/// supersedes the v0.9.7 `name` / `icon_and_name` rewrite, since
/// a dropped key needs no spelling fixed first.
///
/// Like `resize.feedback`'s (#1255), this step changes no VALUE:
/// `AppBarStyle` no longer declares the key, so a stored one is
/// ignored with or without this run. It ends the file in the new
/// shape, since a dead entry left in a saved config reads as a
/// choice somebody made. Reaches a profile's `settings` and a
/// bundle's inline profiles; `gui.json` and the look and palette
/// libraries never carried the key (`LookKeys` left it out).
extension ConfigMigration {
    /// Spelled rather than derived: a historical step keeps
    /// naming what it was written to name.
    static let retiredAppBarContentKey = "content"
    static let appBarContentParentKey = "app_bar"

    @Sendable
    static func migratingRetiredAppBarContent(_ data: Data) -> Data? {
        let needle = Data("\"\(retiredAppBarContentKey)\"".utf8)
        return surgicallyApplying(
            data,
            gate: { $0.range(of: needle) != nil },
            rewriting: withoutAppBarContent,
            editing: surgicallyDroppedAppBarContent
        )
    }

    /// Deletes every string-valued `content` entry from the raw
    /// text, keeping the file's formatting and its Doubles. The
    /// text cannot see a parent, so it drops them all; the
    /// envelope keeps the edit only where it agrees with the
    /// scoped walk, and falls back to the walk otherwise.
    static func surgicallyDroppedAppBarContent(_ text: String) -> Data? {
        let entry =
            "\"\(retiredAppBarContentKey)\"\\s*:\\s*\"(?:[^\"\\\\]|\\\\.)*\""
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

    /// Tree walker dropping the key from every object under an
    /// `app_bar` key, at any depth — the global bar and a
    /// layout's override are both `app_bar`. Scoped to that
    /// parent, never `content` at any depth: a common word, which
    /// a later config gaining elsewhere would lose silently.
    static func withoutAppBarContent(_ node: Any) -> (Any, Bool) {
        if let dict = node as? [String: Any] {
            var out: [String: Any] = [:]
            var changed = false
            for (key, value) in dict {
                let (child, childChanged) = withoutAppBarContent(value)
                if key == appBarContentParentKey,
                    var bar = child as? [String: Any],
                    bar[retiredAppBarContentKey] != nil
                {
                    bar[retiredAppBarContentKey] = nil
                    out[key] = bar
                    changed = true
                    continue
                }
                out[key] = child
                changed = changed || childChanged
            }
            return (out, changed)
        }
        if let array = node as? [Any] {
            var out: [Any] = []
            var changed = false
            for value in array {
                let (child, childChanged) = withoutAppBarContent(value)
                out.append(child)
                changed = changed || childChanged
            }
            return (out, changed)
        }
        return (node, false)
    }
}
