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
/// Deleting a migration is a decision with a format floor (#902).
/// Both `Profile` and `GuiConfig` carry a format integer (with
/// absent meaning format 0, the unversioned legacy format),
/// matching `SetupBundle.currentFormat`.
///
/// Removing an old migration means advancing the minimum
/// supported format floor: files below the floor are refused
/// explicitly rather than failing silently on an upgrade.
/// `init.lua` is deliberately out of scope. A hand-written
/// `app_bar.set_content("icon_and_name")` now fails, but it fails
/// as ONE line reporting `expected one of icon|title|
/// icon_and_title` — the user's own script, which KiwiDesk does
/// not own or rewrite, and a refusal that names the fix. The
/// crossing exists for files this app WROTE, where the user made
/// no choice that could be reported back to them.
///
/// A SECOND Lua store sits inside that carve-out, and it is
/// worth naming because it is easy to miss: a keybinding's `lua`
/// rides inside `gui.json` and inside every profile
/// (`layers[].bindings[].lua`), so a file this app rewrites does
/// carry user-authored Lua. A renamed VERB breaks such a binding
/// — `animations.set_scroll_speed(300)` after #1020 — and is
/// still not migrated, for `init.lua`'s reason exactly: the text
/// is the user's own, the failure is LOUD at press time rather
/// than silent, and AGENTS.md §5 rules a verb rename free of
/// aliases. What this crosses is the config VOCABULARY around
/// the script, never the script.
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
    /// That breadth is bounded by this map, not by the walk, so a
    /// second `content` CodingKey anywhere in the config would
    /// break the bound — and `readBackup` runs the walk across a
    /// whole `SetupBundle`, so the reach is wider than the two
    /// types this reasons about. Such a key owes the walk a path,
    /// or this map a narrower home;
    /// `ConfigMigrationRoutingTests` is what says so on arrival.
    static let retiredBarContent = [
        "name": "title",
        "icon_and_name": "icon_and_title",
    ]

    /// Every migration, oldest first.
    ///
    /// The ORDERED list is the extension point, and the reason
    /// the wired seam below is `migrated(_:)` rather than any one
    /// migration's name: a reader names the seam, never a step,
    /// so a new migration lands here instead of re-editing every
    /// reader and re-asking which readers exist
    /// (`ConfigMigrationRoutingTests` is the census). Each step
    /// takes the bytes as they stand after the previous one.
    ///
    /// **A step added here is not yet a step that RUNS.**
    /// `needsMigration` short-circuits on
    /// `format >= targetFormat(for:)`, so a step owes a
    /// `currentFormat` bump on EVERY shape it must reach — and
    /// without one it is dead on arrival, silently, on exactly
    /// the files it exists to rescue. #1020 is the worked
    /// example: the rename it crosses would otherwise decode to
    /// a DEFAULT rather than fail, so nothing anywhere would
    /// report it. `ScrollDurationMigrationTests` pins that
    /// rename against a `Profile.currentFormat - 1` fixture;
    /// nothing pins the coupling itself, which is why it is
    /// stated here, at the point where a step is added.
    private static let steps: [@Sendable (Data) -> Data?] = [
        migratingLegacyPalettesArray,
        migratingRetiredBarContent,
        migratingRetiredScrollSpeed,
    ]

    /// Target format integer for `root`'s shape (#902, #938, #939).
    static func targetFormat(for root: [String: Any]) -> Int {
        if root[SetupBundle.shapeMarker] != nil {
            return SetupBundle.currentFormat
        }
        if root[Profile.CodingKeys.monitorSets.rawValue] != nil
            || root["monitorSets"] != nil
        {
            return Profile.currentFormat
        }
        let palettes =
            PaletteDocument.CodingKeys.palettes.rawValue
        if root[palettes] != nil {
            return PaletteDocument.currentFormat
        }
        return GuiConfig.currentFormat
    }

    /// Whether `data` is below the current format version for
    /// its shape (#902).
    ///
    /// Formats at or above current format skip migrations
    /// entirely — avoiding JSON parsing and key scans on every
    /// config read once a file carries the format stamp.
    static func needsMigration(_ data: Data) -> Bool {
        guard
            let json = try? JSONSerialization.jsonObject(
                with: data
            )
        else { return false }
        if json is [Any] {
            return true
        }
        guard let root = json as? [String: Any] else { return false }
        let format = root["format"] as? Int ?? 0
        return format < targetFormat(for: root)
    }

    /// `data` with every applicable migration applied, or nil
    /// when none applied.
    ///
    /// Nil rather than the unchanged bytes, deliberately: a
    /// caller writes back exactly when this returns non-nil, so
    /// a config that needs nothing is never rewritten and its
    /// mtime never moves.
    public static func migrated(_ data: Data) -> Data? {
        guard needsMigration(data) else { return nil }
        var current = data
        for step in steps {
            if let next = step(current) {
                current = next
            }
        }
        // A stale format whose bytes no step rewrites is still
        // a crossing that must END (#938): stamp it anyway, or
        // the file re-enters `needsMigration` on every read
        // forever and the next floor advance (#902) refuses a
        // valid file this app wrote. Nil only when the result
        // is byte-identical, preserving the
        // never-rewrite-untouched contract above.
        let result = stamped(current)
        return result == data ? nil : result
    }

    /// `data` with every retired bar-content value rewritten, or
    /// nil when there was nothing to rewrite.
    ///
    /// The envelope — gate, parse, surgical edit, verify, fall
    /// back — is `surgicallyApplying`, which owns the argument
    /// for all three steps. What is local here is the walk.
    @Sendable
    static func migratingRetiredBarContent(
        _ data: Data
    ) -> Data? {
        surgicallyApplying(
            data,
            gate: { $0.range(of: Data("\"content\"".utf8)) != nil },
            rewriting: rewritten,
            editing: surgicallyEdited
        )
    }

    /// `text` with each retired `content` VALUE replaced where it
    /// is the value of a `content` key, leaving every other byte
    /// exactly as it was.
    ///
    /// The pattern requires the opening quote, so
    /// `"icon_and_name"` can never be matched by the `"name"`
    /// entry and the two are order-independent.
    private static func surgicallyEdited(_ text: String) -> Data? {
        var out = text
        for (retired, mapped) in retiredBarContent {
            out = out.replacingOccurrences(
                of: "(\"content\"\\s*:\\s*)\"\(retired)\"",
                with: "$1\"\(mapped)\"",
                options: .regularExpression
            )
        }
        return out == text ? nil : out.data(using: .utf8)
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
