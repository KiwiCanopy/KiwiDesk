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
    ///
    /// The TARGET is spelled here rather than read off
    /// `AnimationSettings.CodingKeys`, and that is deliberate:
    /// a historical step must keep emitting the name it was
    /// written to emit, so that a LATER step can rename that
    /// name again and the two compose. Derive it and this step
    /// silently starts writing whatever the live key is today,
    /// skipping every intermediate crossing. It cannot rot
    /// unnoticed — the routing guard's set EQUALITY reds if
    /// `AnimationSettings` stops declaring it.
    static let retiredScrollSpeedKey = "scroll_speed"
    static let scrollDurationKey = "scroll_duration"

    /// `data` with the retired key renamed wherever it appears,
    /// or nil when there was nothing to rename.
    ///
    /// The envelope — gate, parse, surgical edit, verify, fall
    /// back — is `surgicallyApplying`, which owns the argument
    /// for all three steps. What is local here is the walk and
    /// its both-spellings rule.
    @Sendable
    static func migratingRetiredScrollSpeed(
        _ data: Data
    ) -> Data? {
        let needle = Data("\"\(retiredScrollSpeedKey)\"".utf8)
        return surgicallyApplying(
            data,
            gate: { $0.range(of: needle) != nil },
            rewriting: renamed,
            editing: surgicallyRenamed
        )
    }

    /// `text` with the retired KEY renamed, leaving every other
    /// byte exactly as it was — or nil to hand the job to the
    /// tree.
    ///
    /// The trailing `:` is required, so a string VALUE that
    /// happens to read `"scroll_speed"` — a space named that, a
    /// palette named that — is never touched. Only a key is.
    ///
    /// **It stands down when the target key is already present,
    /// and that is not caution — it is the one case this cannot
    /// do correctly** (`code-reviewer`, 2026-08-27). A textual
    /// rename cannot see a sibling, so a node carrying both
    /// spellings becomes a node carrying the SAME key twice.
    /// The envelope's re-parse/compare net structurally cannot
    /// catch it: `JSONSerialization` silently keeps the FIRST
    /// occurrence, and `.sortedKeys` — which `ProfileManager`
    /// writes with — puts `scroll_duration` first, so the
    /// duplicate decodes to the RIGHT value and compares equal.
    /// The bytes would then be written to disk and stamped
    /// current, with Foundation reading 420 and `jq`/Python
    /// reading the stale 50 out of one file (measured, both
    /// ways). The walk handles this case exactly; the edit hands
    /// it over.
    static func surgicallyRenamed(
        _ text: String
    ) -> Data? {
        guard
            text.range(
                of: "\"\(scrollDurationKey)\"\\s*:",
                options: .regularExpression
            ) == nil
        else { return nil }
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
    static func renamed(_ node: Any) -> (Any, Bool) {
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
