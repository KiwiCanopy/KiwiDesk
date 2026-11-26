import KiwiDeskCore
import SwiftUI

/// The saved tiles' wallpaper badge and drop cue (#3478): the badge
/// opens the wallpaper items of the tile's own menu, built by the
/// one `menuItem`, so its labels cannot drift from the row menu's
/// (#845).
extension LooksShelf {
    func wallpaperBadge(_ look: ShelfLook) -> some View {
        LookWallpaperBadge(wallpaper: look.admitted.wallpaper) {
            ForEach(Self.wallpaperMenu, id: \.id) { key in
                menuItem(key, look, divides: false)
            }
        }
    }

    /// The row menu's wallpaper items, in its order.
    static var wallpaperMenu: [SettingKey] {
        ColorsRowOrder.looksContextMenu.filter {
            switch $0 {
            case .colours(.lookChooseWallpaper),
                .colours(.lookUseCurrentWallpaper),
                .colours(.lookRemoveWallpaper):
                true
            default: false
            }
        }
    }

    /// Keeps the tile under a dragged picture marked; a tile the
    /// drag leaves clears only its own mark.
    func dropTargeted(_ over: Bool, _ look: ShelfLook) {
        if over {
            dropTarget = look.name
        } else if dropTarget == look.name {
            dropTarget = nil
        }
    }

    /// Teaches the drop while no saved look holds a picture.
    @ViewBuilder var wallpaperHint: some View {
        if !model.userLooks.isEmpty,
            !model.userLooks.contains(where: { $0.wallpaper != nil })
        {
            Text(
                L(
                    "looks.wallpaper.hint",
                    "Drop a picture on a look to give it a wallpaper."
                )
            )
            .font(.caption)
            .foregroundStyle(SettingsTheme.ink3)
        }
    }
}
