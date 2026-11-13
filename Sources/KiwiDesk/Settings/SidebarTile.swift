import SwiftUI

/// System-Settings-style icon tile.
struct SidebarTile: View {
    let destination: SettingsDestination
    /// An `accentInk` edge, for a tile drawn on the accent — a
    /// dropdown's cursor row — where Profiles' own accent tile
    /// would otherwise lose its outline.
    var edged = false

    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(destination.tileFill)
            .frame(
                width: SettingsMetrics.sidebarTile,
                height: SettingsMetrics.sidebarTile
            )
            .overlay {
                Image(systemName: destination.symbol)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white)
            }
            .overlay {
                if edged {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(SettingsTheme.accentInk)
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
