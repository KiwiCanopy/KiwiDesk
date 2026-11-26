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
    static var size: CGFloat { 22 }
    static var inset: CGFloat { 4 }

    var body: some View {
        Menu {
            items()
        } label: {
            Self.face(symbol: symbol, hovered: hovered)
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

    /// The badge as drawn: an opaque chip on the card's ground with
    /// its edge, so it reads on any plate or picture; the pointer
    /// lifts its fill (owner, 2026-11-26).
    static func face(symbol: String, hovered: Bool) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(SettingsTheme.ink)
            .frame(width: size, height: size)
            .background(
                hovered ? SettingsTheme.chipHover : .clear,
                in: Circle()
            )
            .background(SettingsTheme.card, in: Circle())
            .overlay(
                Circle().strokeBorder(SettingsTheme.hairline, lineWidth: 1)
            )
            .contentShape(Circle())
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
