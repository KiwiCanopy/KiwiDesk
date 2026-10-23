import SwiftUI

/// A strip picture's pointer half (#2537): the click that lands on
/// its entry, and under the pointer an accent border and the
/// pointing hand, the one cue that the picture is a link. Its own
/// view, so a hover redraws the border alone and never rebuilds the
/// picture beneath (owner ruling 2026-10-18).
struct GestureStripHoverCue: View {
    let onTap: () -> Void
    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        RoundedRectangle(cornerRadius: SettingsTheme.disclosureRadius)
            .strokeBorder(SettingsTheme.accent, lineWidth: 2)
            .opacity(hovering ? 1 : 0)
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
            .onHover { hovering = $0 }
            .pointingHandCursor()
            // `HoverChip`'s duration, as the Home cards take it.
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.12),
                value: hovering
            )
    }
}
