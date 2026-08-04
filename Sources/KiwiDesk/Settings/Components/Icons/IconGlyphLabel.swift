import AppKit
import SwiftUI

/// Renders an icon string: an SF Symbol if the string names
/// one, otherwise the literal character(s); a placeholder
/// symbol when empty.
struct IconGlyphLabel: View {
    let icon: String
    var placeholder: String?

    var body: some View {
        if icon.isEmpty {
            if let placeholder {
                Image(systemName: placeholder)
            } else {
                // No "Choose…" text: the label stays
                // glyph-sized so pickers line up uniformly
                // whether or not an icon is set (the button's
                // tooltip carries the hint).
                //
                // A CONCRETE ink, not `.secondary`: hierarchical
                // styles derive from the enclosing foreground, and
                // a space row draws its glyphs in the accent — so
                // `.secondary` here rendered the "no icon yet"
                // placeholder as translucent green ON green, which
                // reads as a grey film over the row rather than as
                // an empty slot (owner, 2026-08-04). The set-icon
                // branches below inherit the row's colour on
                // purpose; only the placeholder needs to stand
                // apart from it.
                Image(systemName: "face.smiling")
                    .foregroundStyle(SettingsTheme.ink3)
            }
        } else if isSymbol {
            Image(systemName: icon)
        } else {
            Text(icon)
        }
    }

    private var isSymbol: Bool {
        !icon.isEmpty
            && NSImage(
                systemSymbolName: icon,
                accessibilityDescription: nil
            ) != nil
    }
}
