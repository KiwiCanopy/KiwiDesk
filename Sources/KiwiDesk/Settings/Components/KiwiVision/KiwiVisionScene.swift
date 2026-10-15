import KiwiDeskCore
import SwiftUI

/// KiwiVision's picture (#2103), drawn in the schematic language:
/// the user's palette, gaps and focus ring. Every verdict is
/// Core's — the veil at the plate's own dim mapping, the softening
/// only where the plate's blur door draws, the windows in the
/// appearance the mode will show. The focused window and the menu
/// bar sit above the veil, as the plate sits under the ring. With
/// the wallpaper clear the veil goes on each hazed window instead,
/// so the desk and the gaps stay bright, as the plate's mask does.
struct KiwiVisionScene: View {
    /// The dim in percent, as stored.
    let dimPercent: Double
    let blurs: Bool
    /// Whether the wallpaper stays clear (#2103 ruling 17).
    var windowsOnly = false
    let darkWindows: Bool
    let settings: TilingSettings

    static let size = CGSize(width: 348, height: 218)
    private static let menuBar: CGFloat = 6

    private var palette: SchematicPalette {
        HomeCardPlate.palette(settings)
    }

    private var veil: Double {
        VisionPlateDim.opacity(forDim: dimPercent / 100)
    }

    var body: some View {
        ZStack(alignment: .top) {
            palette.base
            grid(focusedLayer: false)
            SettingsTheme.visionVeil.opacity(windowsOnly ? 0 : veil)
            grid(focusedLayer: true)
            Rectangle()
                .fill(palette.ink.opacity(0.25))
                .frame(height: Self.menuBar)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4).strokeBorder(palette.frame)
        )
    }

    /// The 2×2 desk at the user's gaps; one pass draws the hazed
    /// windows, the other only the focused one, so the veil goes
    /// between them.
    private func grid(focusedLayer: Bool) -> some View {
        let outer = settings.gapsGlobal.outer
        let inner = settings.gapsGlobal.inner
        let mini = GapPreviewScale.mini
        return VStack(spacing: mini(inner.vertical)) {
            HStack(spacing: mini(inner.horizontal)) {
                pane(.document, focused: true, layer: focusedLayer)
                pane(.browser, focused: false, layer: focusedLayer)
            }
            HStack(spacing: mini(inner.horizontal)) {
                pane(.chat, focused: false, layer: focusedLayer)
                pane(.calendar, focused: false, layer: focusedLayer)
            }
        }
        .padding(.top, Self.menuBar + mini(outer.top))
        .padding(.bottom, mini(outer.bottom))
        .padding(.leading, mini(outer.left))
        .padding(.trailing, mini(outer.right))
    }

    @ViewBuilder private func pane(
        _ kind: KiwiVisionWindow.Kind,
        focused: Bool,
        layer: Bool
    ) -> some View {
        let window = KiwiVisionWindow(
            kind: kind,
            soft: !focused && blurs,
            accent: palette.accent
        )
        .environment(\.colorScheme, darkWindows ? .dark : .light)
        if focused == layer {
            window.overlay {
                if !focused, windowsOnly {
                    SettingsTheme.visionVeil.opacity(veil)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                if focused, settings.borderStyle.enabled {
                    RoundedRectangle(cornerRadius: 4).strokeBorder(
                        palette.accent,
                        lineWidth: BorderPreviewScale.width(
                            settings.borderStyle.clampedWidth,
                            to: 1...4
                        )
                    )
                }
            }
        } else {
            Color.clear
        }
    }
}
