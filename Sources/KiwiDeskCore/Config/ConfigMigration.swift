import Foundation

/// One-shot rewrites of config files written by an older build.
///
/// A rename lands in this repo without a compatibility alias
/// (AGENTS.md §5) — the config is re-edited instead. That rule
/// rests on a premise, "pre-release, single user", and the
/// premise expired: v0.9.7 shipped to other people. So a rename
/// made after it needs a way across, and this is the shape that
/// has an END, which an alias does not: the value is rewritten
/// in the file, once, and then this code is dead by construction
/// rather than by anyone remembering.
///
/// What it is NOT is a decode-time fold. A lenient decoder keeps
/// accepting the retired spelling forever, because nothing ever
/// signals that the last config carrying it is gone — which is
/// exactly the shim §5 bans, and exactly what this branch
/// removed twice before understanding why it kept coming back.
///
/// Deleting this is a real decision and needs a real signal.
/// Neither `Profile` nor `GuiConfig` carries a format stamp, so
/// nothing here can prove a given config has been through the
/// rewrite — a user upgrading across several versions at once
/// skips whichever build would have done it. Until those files
/// carry a version — `SetupBundle.currentFormat` is the pattern,
/// applied to the two files read on every launch — removing this
/// is a guess, and the guess fails silently on someone else's
/// machine.
/// `init.lua` is deliberately out of scope. A hand-written
/// `app_bar.set_content("icon_and_name")` now fails, but it fails
/// as ONE line reporting `expected one of icon|title|
/// icon_and_title` — the user's own script, which KiwiDesk does
/// not own or rewrite, and a refusal that names the fix. The
/// crossing exists for files this app WROTE, where the user made
/// no choice that could be reported back to them.
public enum ConfigMigration {
    /// The `app_bar.content` spellings retired when the bars
    /// began naming the WINDOW rather than its app (owner ruling
    /// 2026-08-19), mapped onto what this build reads.
    ///
    /// Both bar-content sites decode from the same vocabulary —
    /// `AppBarStyle.content` and a layout's `LayoutAppBar`
    /// override — which is why the walk below rewrites by KEY at
    /// any depth instead of hardcoding a path per layout: an
    /// override sits one level down from the global style, and a
    /// migration that reached only the global one would leave the
    /// file just as undecodable.
    ///
    /// That breadth is bounded by the map, not by the walk, and a
    /// SECOND `content` CodingKey elsewhere in the config would
    /// break the bound — such a key owes this walk a path, or
    /// this map a narrower home. Two declare it today
    /// (`AppBarStyle+Coding`, `LayoutAppBar`); nothing guards
    /// that count.
    static let retiredBarContent = [
        "name": "title",
        "icon_and_name": "icon_and_title",
    ]

    /// `data` with every retired bar-content value rewritten, or
    /// nil when there was nothing to rewrite.
    ///
    /// Nil rather than the unchanged bytes, deliberately: the
    /// callers write back exactly when this returns non-nil, so
    /// a config that needs nothing is never rewritten and its
    /// mtime never moves.
    public static func migratingRetiredBarContent(
        _ data: Data
    ) -> Data? {
        // Cheap gate first: a config that never set the bar's
        // content — the common case, since every field is sparse
        // — costs one substring scan rather than a parse.
        guard data.range(of: Data("\"content\"".utf8)) != nil
        else { return nil }
        guard
            let root = try? JSONSerialization.jsonObject(with: data)
        else { return nil }
        let (migrated, changed) = rewritten(root)
        guard changed else { return nil }
        return try? JSONSerialization.data(
            withJSONObject: migrated,
            options: [.prettyPrinted, .sortedKeys]
        )
    }

    /// The tree with retired `content` values replaced, plus
    /// whether anything changed.
    private static func rewritten(_ node: Any) -> (Any, Bool) {
        if let dict = node as? [String: Any] {
            var out: [String: Any] = [:]
            var changed = false
            for (key, value) in dict {
                if key == "content", let raw = value as? String,
                    let mapped = retiredBarContent[raw]
                {
                    out[key] = mapped
                    changed = true
                    continue
                }
                let (child, childChanged) = rewritten(value)
                out[key] = child
                changed = changed || childChanged
            }
            return (out, changed)
        }
        if let array = node as? [Any] {
            var out: [Any] = []
            var changed = false
            for value in array {
                let (child, childChanged) = rewritten(value)
                out.append(child)
                changed = changed || childChanged
            }
            return (out, changed)
        }
        return (node, false)
    }
}
