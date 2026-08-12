import Foundation
import KiwiDeskCore

/// The reference rows' glyph and combo rendering — split from
/// `ShortcutsReference+Bands.swift` at the §2.1 target when the
/// Inactive band pushed that file past it (#820). Panel-only by
/// intent rather than by access control: the split cost these
/// `private`, so keeping the shared catalog and the editor rows
/// untouched is now an obligation on a future caller, not
/// something the compiler holds.
extension ShortcutsReferenceBuilder {
    /// A directional SF Symbol for a compass-direction command
    /// (`focus`/`swap` left/right/up/down) — the one clearly-spatial
    /// glyph the hybrid symbol scheme adds beyond space/app icons.
    /// Non-spatial commands (prev/next track, resize axes,
    /// switch-layer, custom Lua) stay label-only by design. Keep
    /// it panel-only — the shared catalog and the editor rows
    /// carry their own icons, and a second caller here would put
    /// an arrow on rows that were ruled label-only.
    static func directionalIcon(for lua: String) -> String? {
        // A space or layer literally named a direction word would
        // otherwise false-match on the substring — those commands own
        // their own glyphs (space fallback / none), so bail first.
        guard !lua.contains("_space"),
            !lua.contains("switch_layer")
        else { return nil }
        if lua.contains("\"left\"") { return "arrow.left" }
        if lua.contains("\"right\"") { return "arrow.right" }
        if lua.contains("\"up\"") { return "arrow.up" }
        if lua.contains("\"down\"") { return "arrow.down" }
        return nil
    }

    /// A fallback glyph for a space command whose space has no
    /// custom icon: the space number in a square (`3.square`) — a
    /// space-shaped symbol carrying the number, matching how the row
    /// reads ("Go to Space 3"). Do NOT route the Space Bar's
    /// plain-digit fallback through here, or this through it:
    /// this is a symbol slot in a list row with no boxed
    /// wrapper, so the bar's box-in-a-box problem (QA
    /// 2026-07-19) — the reason that one drops the symbol — does
    /// not apply to it. Non-numeric space ids get the
    /// generic Spaces glyph. Nil for non-space commands.
    static func spaceFallbackIcon(
        for lua: String
    ) -> String? {
        guard lua.contains("_space") else { return nil }
        if let id = quotedArg(in: lua), let n = Int(id),
            (0...50).contains(n)
        {
            return "\(n).square"
        }
        return "squares.below.rectangle"
    }

    /// The first double-quoted argument in a Lua call, e.g. `"3"`
    /// from `KiwiDesk.focus_space("3")`.
    private static func quotedArg(in lua: String) -> String? {
        guard let open = lua.range(of: "(\"") else { return nil }
        let rest = lua[open.upperBound...]
        guard let close = rest.range(of: "\"") else { return nil }
        return String(rest[..<close.lowerBound])
    }

    /// The combo string rendered as native glyphs via the same
    /// `ComboSymbols` + layout path the editor uses — so a combo
    /// is pixel-identical across the two surfaces. A parse failure
    /// falls back to the raw stored string.
    static func glyphs(_ combo: String) -> String {
        guard let parsed = KeyCombo.parse(combo) else {
            return combo
        }
        return ComboSymbols.render(
            parsed,
            layoutChar: LayoutKeyGlyph.char
        )
    }
}
