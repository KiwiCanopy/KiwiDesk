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
}
