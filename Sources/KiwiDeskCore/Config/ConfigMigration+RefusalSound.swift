import Foundation

/// Retires `resize.feedback` (#1255, `ConfigMigrationRoutingTests`,
/// `RefusalSoundMigrationTests`).
///
/// The setting stopped being a resize one — every refusal that
/// draws a pill may now sound — so it moved to `refusal.sound`
/// and its default flipped OFF. That flip is why this DROPS the
/// old key rather than carrying its value across: the encoder
/// wrote `feedback` unconditionally, so every saved config holds
/// an explicit `true` nobody chose, and carrying it would hand a
/// widened cue to installs that never asked for one.
///
/// Dropping is a complete crossing here because absence decodes
/// as the new default: `decodeRefusal` returns early with no
/// `refusal` group, leaving the property at `false`, and the next
/// save writes the new key. So the file ENDS in the new shape
/// rather than being read leniently forever.
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
            editing: { _ in nil }
        )
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
