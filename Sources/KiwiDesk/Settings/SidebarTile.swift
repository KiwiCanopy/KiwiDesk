import SwiftUI

/// System-Settings-style icon tile with optional badge dot.
struct SidebarTile: View {
    let destination: SettingsDestination
    /// Accent dot on tile corner for notifications.
    var badged = false

    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(destination.tint)
            .frame(
                width: SettingsMetrics.sidebarTile,
                height: SettingsMetrics.sidebarTile
            )
            .overlay {
                Image(systemName: destination.symbol)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white)
            }
            // The badge must not be the colour of the tile it
            // sits on, and one tile IS the accent: Profiles is
            // the only destination that is ever badged, and its
            // tint is `SettingsTheme.accent`. So the dot is drawn
            // in `card` with an accent ring — legible on every
            // tint, including its own, and for every viewer
            // rather than only for those who can separate the two
            // greens.
            .overlay(alignment: .topTrailing) {
                if badged {
                    Circle()
                        .fill(SettingsTheme.card)
                        .frame(width: 7, height: 7)
                        .overlay(
                            Circle().strokeBorder(
                                SettingsTheme.ink,
                                lineWidth: 1
                            )
                        )
                        .offset(x: 2, y: -2)
                }
            }
            // The soft lift System Settings gives its sidebar
            // icons — kept inside `inactiveDimmed` so the
            // shadow fades with the tile.
            .shadow(
                color: .black.opacity(0.25),
                radius: 1.5,
                y: 1
            )
            // The colored fill has no notion of window key
            // state; System Settings' tiles fade, hue kept
            // (#297).
            .inactiveDimmed()
    }
}
