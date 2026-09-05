import Foundation

/// Retires `resize.feedback` (#1255, `ConfigMigrationRoutingTests`,
/// `RefusalSoundMigrationTests`).
///
/// The setting stopped being a resize one — every refusal that
/// draws a pill may now sound — so it moved to `refusal.sound`
/// and its default flipped OFF.
///
/// This step changes no VALUE, and saying otherwise would
/// mislead the next rename: `ResizeKeys` no longer declares
/// `feedback`, so a stored `true` is an unknown key the decoder
/// ignores, and the OFF default lands with or without this run.
/// What it does is end the file in the new shape — a dead entry
/// left in a saved config reads as a choice somebody made, and
/// the encoder wrote that entry into every file unconditionally
/// under the old default, so nobody did.
///
/// Carrying the value was refused for that reason: an explicit
/// `true` records what a save did, not what a user chose, and
/// the cue widened from one near-unreachable case to every
/// refusal.
extension ConfigMigration {
    /// The retired key, spelled here rather than derived: a
    /// historical step must keep naming what it was written to
    /// name, so a LATER rename composes on top of it instead of
    /// skipping this crossing (the `scroll_speed` precedent).
    static let retiredResizeFeedbackKey = "feedback"

    @Sendable
    static func migratingRetiredResizeFeedback(
        _ data: Data
    ) -> Data? {
        let needle = Data(
            "\"\(retiredResizeFeedbackKey)\"".utf8
        )
        return surgicallyApplying(
            data,
            gate: { $0.range(of: needle) != nil },
            rewriting: withoutResizeFeedback,
            editing: surgicallyDropped
        )
    }

    /// Surgically deletes the entry from raw JSON text, so a
    /// user's file keeps its own formatting and its Doubles keep
    /// their precision (the envelope's docstring carries the
    /// measurement). Stands down unless the retired spelling
    /// occurs exactly once: a textual delete cannot see which
    /// parent it is under, and the tree walk — which can — is
    /// the fallback — and the fallback is CORRECT, never merely
    /// tolerable: `surgicallyApplying` re-parses whatever this
    /// returns and uses it only where it agrees with the walk.
    /// So a widened stand-down costs the user's byte-for-byte
    /// formatting, never the migration (guard-prover 2026-09-05;
    /// the walk's own scoping is `ConfigMigrationRoutingTests`').
    static func surgicallyDropped(_ text: String) -> Data? {
        let key = "\"\(retiredResizeFeedbackKey)\""
        guard text.components(separatedBy: key).count == 2
        else { return nil }
        let entry = key + "\\s*:\\s*(true|false)"
        for pattern in [
            entry + "\\s*,\\s*", "\\s*,\\s*" + entry, entry,
        ] {
            let out = text.replacingOccurrences(
                of: pattern,
                with: "",
                options: .regularExpression
            )
            if out != text { return out.data(using: .utf8) }
        }
        return nil
    }

    /// Tree walker dropping the retired key under a `resize`
    /// object. Scoped to that parent rather than by name at any
    /// depth: `feedback` is a common enough word that a future
    /// config gaining one elsewhere would be silently eaten by a
    /// depth-agnostic drop.
    static func withoutResizeFeedback(
        _ node: Any
    ) -> (Any, Bool) {
        if let dict = node as? [String: Any] {
            var out: [String: Any] = [:]
            var changed = false
            for (key, value) in dict {
                let (child, childChanged) =
                    withoutResizeFeedback(value)
                if key == "resize",
                    var resize = child as? [String: Any],
                    resize[retiredResizeFeedbackKey] != nil
                {
                    resize[retiredResizeFeedbackKey] = nil
                    out[key] = resize
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
                let (child, childChanged) =
                    withoutResizeFeedback(value)
                out.append(child)
                changed = changed || childChanged
            }
            return (out, changed)
        }
        return (node, false)
    }
}
