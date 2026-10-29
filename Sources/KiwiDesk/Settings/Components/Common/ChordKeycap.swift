import SwiftUI

/// One key drawn as a keycap, the tour's and Simple's KiwiHub line
/// (#2737): shown, never pressed, so it carries no hover or button
/// trait. The accent fill is the tour's gateway chord alone.
struct ChordKeycap: View {
    let text: String
    /// A sided modifier's side word, drawn small before its glyph.
    var side: String?
    var accent = false

    var body: some View {
        HStack(spacing: 3) {
            if let side {
                Text(side)
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(SettingsTheme.ink3)
            }
            Text(text)
        }
        .font(.system(size: 12, weight: .semibold).monospaced())
        .foregroundStyle(
            accent ? SettingsTheme.accentInk : SettingsTheme.ink
        )
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(accent ? SettingsTheme.accent : SettingsTheme.sunken)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(
                    accent
                        ? SettingsTheme.accentInk.opacity(0.22)
                        : SettingsTheme.ink2.opacity(0.3),
                    lineWidth: 1.2
                )
        )
        .fixedSize()
    }

    /// The "+" between two caps.
    static var plus: some View {
        Text(verbatim: "+")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(SettingsTheme.ink3)
            .padding(.vertical, 4)
    }
}
