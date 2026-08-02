import SwiftUI

/// A System-Settings-style icon tile: white glyph on a flat
/// rounded-rect color (§6.1).
struct SidebarTile: View {
    let destination: SettingsDestination
    /// Accent dot on the tile's top-trailing corner — the
    /// native "something to look at in this section" cue.
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
            .overlay(alignment: .topTrailing) {
                if badged {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 7, height: 7)
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
