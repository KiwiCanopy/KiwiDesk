import KiwiDeskCore
import SwiftUI

/// The wallpaper badge on a saved look's plate (#3478): drawn at
/// rest, it says whether the look carries a picture and opens the
/// wallpaper items of the tile's own menu (ui-patterns ▸ hover never
/// creates the only affordance). Out of VoiceOver and the focus
/// loop: the tile's accessibility actions and ⌃. carry the same
/// items, so a second stop per tile would add nothing.
struct LookWallpaperBadge<Items: View>: View {
    let wallpaper: LookWallpaper?
    @ViewBuilder let items: () -> Items
    @State private var hovered = false

    /// The badge's side, in points; it sits this far inside the
    /// plate's corner too.
    static var size: CGFloat { 20 }
    static var inset: CGFloat { 4 }

    var body: some View {
        Menu {
            items()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(
                    wallpaper == nil ? SettingsTheme.ink2 : SettingsTheme.ink
                )
                .frame(width: Self.size, height: Self.size)
                .background(
                    hovered ? SettingsTheme.chipHover : SettingsTheme.chipRest,
                    in: Circle()
                )
                // A picture under the badge can be any colour; the
                // material keeps the chip legible over it.
                .background(.ultraThinMaterial, in: Circle())
                .contentShape(Circle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .neutralMenuLabel()
        .menuIndicator(.hidden)
        .fixedSize()
        .onHover { hovered = $0 }
        .help(help)
        .focusable(false)
        .accessibilityHidden(true)
    }

    /// The shape carries the state, never the colour.
    private var symbol: String { Self.symbol(for: wallpaper) }

    static func symbol(for wallpaper: LookWallpaper?) -> String {
        switch wallpaper?.count ?? 0 {
        case 0: "photo.badge.plus"
        case 1: "photo.fill"
        default: "photo.stack.fill"
        }
    }

    private var help: String {
        wallpaper == nil
            ? L("looks.wallpaper.badge.add", "Add a wallpaper to this look")
            : L(
                "looks.wallpaper.badge.change",
                "Change or remove this look's wallpaper"
            )
    }
}

/// What a saved tile draws while a picture file is dragged over it
/// (#3478): a tint wash under a pill naming the drop. The applied
/// stroke stays the accent's alone.
struct LookWallpaperDropCue: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: PaletteSceneThumbnail.plateRadius)
                .fill(.tint.opacity(0.2))
            Text(L("looks.wallpaper.drop", "Drop to Set Wallpaper"))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(SettingsTheme.ink)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.regularMaterial, in: Capsule())
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
