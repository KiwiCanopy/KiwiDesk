import Foundation

/// The `animations.scroll_speed` → `animations.scroll_duration`
/// crossing (#1020) — the first step that renames a **key**
/// where the other two rewrite a value or a shape.
///
/// Why it needs a crossing at all: the setting is the
/// focus-shift animation's DURATION, so "speed" ran backwards —
/// raising it made scrolling slower. The Lua verb and the label
/// moved with it, and neither owes anything (nothing external
/// depends on a command name, AGENTS.md §5). The stored key
/// does.
///
/// **The failure this prevents is silent, not loud.**
/// `AnimationSettings` decodes each knob with
/// `decodeIfPresent ?? 150`, which is the missing-keys contract
/// a sparse profile relies on — so a file still carrying
/// `scroll_speed` does not fail to decode. It decodes with the
/// user's tuned value replaced by the default, reports success,
/// and is then saved back without the old key. A refusal would
/// at least be visible; this would not be.
///
/// Reaching every reader is therefore the whole point.
/// `animations` hangs off `TilingSettings`, and the file shapes
/// that actually STORE one are `Profile.settings` and
/// `SetupBundle`, which carries `[Profile]` inline.
/// `GuiConfig` looks like a third and is not: its `settings`
/// property is absent from `CodingKeys`, so it never reaches
/// `gui.json` — checked rather than assumed, and recorded at
/// `GuiConfig.currentFormat` so the next rename does not
/// re-derive it. `ConfigMigrationRoutingTests` is the census of
/// the readers; `ScrollDurationMigrationTests` exercises both
/// shapes rather than trusting this sentence.
extension ConfigMigration {
    /// The retired key, and what this build reads instead.
    ///
    /// Scoped by NAME, and the name is what bounds it: the walk
    /// below rewrites at any depth, so a second `scroll_speed`
    /// CodingKey anywhere in the config would put a value this
    /// was never scoped to inside its reach.
    /// `ConfigMigrationRoutingTests.scrollDurationKeyStaysUnique`
    /// is what says so on arrival — the same shape as the
    /// `content` guard beside it.
    static let retiredScrollSpeedKey = "scroll_speed"
    static let scrollDurationKey = "scroll_duration"

    /// `data` with the retired key renamed wherever it appears,
    /// or nil when there was nothing to rename.
    @Sendable
    static func migratingRetiredScrollSpeed(
        _ data: Data
    ) -> Data? {
        // Cheap gate first, matching the bar-content step: a
        // config that never tuned the scroll — the common case,
        // since every field is sparse — costs one substring scan
        // rather than a parse.
        let needle = Data("\"\(retiredScrollSpeedKey)\"".utf8)
        guard data.range(of: needle) != nil else { return nil }
        guard
            let root = try? JSONSerialization.jsonObject(with: data)
        else { return nil }
        let (expected, changed) = renamed(root)
        guard changed else { return nil }
        // The parse decides; a TEXTUAL edit applies — the same
        // division the bar-content step documents, and for the
        // same measured reason: re-serializing the tree rewrites
        // every `Double` in the file (`0.4` →
        // `0.40000000000000002`), so a one-key migration would
        // show up as a diff across a config kept in a dotfiles
        // repo. Correctness does not rest on the edit: the
        // result is re-parsed and compared against the tree the
        // walk produced, and anything but an exact match falls
        // back to serializing that tree.
        if let text = String(data: data, encoding: .utf8),
            let edited = surgicallyRenamed(text),
            let reparsed = try? JSONSerialization.jsonObject(
                with: edited
            ),
            canonical(reparsed) == canonical(expected)
        {
            return edited
        }
        return try? JSONSerialization.data(
            withJSONObject: expected,
            options: [.prettyPrinted, .sortedKeys]
        )
    }

    /// `text` with the retired KEY renamed, leaving every other
    /// byte exactly as it was.
    ///
    /// The trailing `:` is required, so a string VALUE that
    /// happens to read `"scroll_speed"` — a space named that, a
    /// palette named that — is never touched. Only a key is.
    private static func surgicallyRenamed(
        _ text: String
    ) -> Data? {
        let out = text.replacingOccurrences(
            of: "\"\(retiredScrollSpeedKey)\"(\\s*:)",
            with: "\"\(scrollDurationKey)\"$1",
            options: .regularExpression
        )
        return out == text ? nil : out.data(using: .utf8)
    }

    /// The tree with the retired key renamed, plus whether
    /// anything changed.
    ///
    /// A node carrying BOTH spellings keeps the new one: the
    /// file was written by a build that already had the rename,
    /// so the retired sibling is stale rather than authoritative.
    private static func renamed(_ node: Any) -> (Any, Bool) {
        if let dict = node as? [String: Any] {
            var out: [String: Any] = [:]
            var changed = false
            for (key, value) in dict {
                let (child, childChanged) = renamed(value)
                if key == retiredScrollSpeedKey {
                    if dict[scrollDurationKey] == nil {
                        out[scrollDurationKey] = child
                    }
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
                let (child, childChanged) = renamed(value)
                out.append(child)
                changed = changed || childChanged
            }
            return (out, changed)
        }
        return (node, false)
    }
}
