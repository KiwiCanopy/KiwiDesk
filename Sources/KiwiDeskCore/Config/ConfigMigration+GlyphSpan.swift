import Foundation

/// Migrates `space_bar.glyph_cap` to `glyph_span` (#1528 item 22,
/// `ConfigMigrationRoutingTests`, `GlyphSpanMigrationTests`): the
/// strip draws one more glyph at a row's end, so "cap" stopped
/// being exact. The value keeps its meaning — the glyphs between
/// the two `+n` discs — so it moves unchanged. Without the step
/// the failure is SILENT: `SpaceBarStyle` decodes the span with
/// `decodeIfPresent ?? default`, dropping a tuned value.
///
/// It reaches a profile's `settings` and a bundle's inline
/// profiles, the two shapes that carry `SpaceBarStyle`; `gui.json`,
/// the palette and look libraries carry no span (`LookKeys` leaves
/// it out).
extension ConfigMigration {
    /// Spelled rather than derived, as #1020's: a historical step
    /// keeps emitting the name it was written to emit.
    static let retiredGlyphCapKey = "glyph_cap"
    static let glyphSpanKey = "glyph_span"

    @Sendable
    static func migratingRetiredGlyphCap(_ data: Data) -> Data? {
        let needle = Data("\"\(retiredGlyphCapKey)\"".utf8)
        return surgicallyApplying(
            data,
            gate: { $0.range(of: needle) != nil },
            rewriting: {
                renamingKey(retiredGlyphCapKey, to: glyphSpanKey, in: $0)
            },
            editing: {
                surgicallyRenamingKey(
                    retiredGlyphCapKey,
                    to: glyphSpanKey,
                    in: $0
                )
            }
        )
    }

    /// The textual rename of `retired` to `target`, standing down
    /// where `target` is already present — a textual edit cannot
    /// see a sibling (#1020's `surgicallyRenamed` argues why).
    static func surgicallyRenamingKey(
        _ retired: String,
        to target: String,
        in text: String
    ) -> Data? {
        guard
            text.range(
                of: "\"\(target)\"\\s*:",
                options: .regularExpression
            ) == nil
        else { return nil }
        let out = text.replacingOccurrences(
            of: "\"\(retired)\"(\\s*:)",
            with: "\"\(target)\"$1",
            options: .regularExpression
        )
        return out == text ? nil : out.data(using: .utf8)
    }

    /// The tree walk renaming `retired` to `target` at any depth;
    /// a node already carrying `target` keeps it.
    static func renamingKey(
        _ retired: String,
        to target: String,
        in node: Any
    ) -> (Any, Bool) {
        if let dict = node as? [String: Any] {
            var out: [String: Any] = [:]
            var changed = false
            for (key, value) in dict {
                let (child, childChanged) = renamingKey(
                    retired,
                    to: target,
                    in: value
                )
                if key == retired {
                    if dict[target] == nil { out[target] = child }
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
                let (child, childChanged) = renamingKey(
                    retired,
                    to: target,
                    in: value
                )
                out.append(child)
                changed = changed || childChanged
            }
            return (out, changed)
        }
        return (node, false)
    }
}
