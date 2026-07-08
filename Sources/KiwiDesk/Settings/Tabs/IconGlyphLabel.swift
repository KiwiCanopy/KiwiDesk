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
                Image(systemName: "face.smiling")
                    .foregroundStyle(.secondary)
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
