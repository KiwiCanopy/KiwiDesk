import KiwiDeskCore
import SwiftUI

/// The plate paint every desk picture resolves (#2859): the light
/// plate where the window is light and the look holds it
/// (`holdsLightPlate`), else the dark plate (#786).
extension HomeCardPlate {
    /// The one paint a picture of `settings` draws in `scheme`.
    static func palette(
        _ settings: TilingSettings,
        in scheme: ColorScheme
    ) -> SchematicPalette {
        guard scheme == .light, holdsLightPlate(settings) else {
            return darkPalette(settings)
        }
        return SchematicPalette(
            accent: SettingsTheme.lightInk,
            ink: SettingsTheme.lightInk,
            base: SettingsTheme.lightPlate,
            ground: .light,
            focus: Color(kiwiHex: settings.borderStyle.focusedColor)
        )
    }

    /// The dark plate's paint, the user's colours folded against
    /// it (ui-designer 2026-08-09). The look tiles (`LookPlate`,
    /// #1740) and KiwiVision's scene keep it in both modes.
    static func darkPalette(
        _ settings: TilingSettings
    ) -> SchematicPalette {
        let accent = settings.kiwishelf.activeItemColor
        let ink = settings.kiwishelf.itemColor
        return SchematicPalette(
            accent: plateLegible(accent, on: darkGround)
                ? Color(kiwiHex: accent)
                : SettingsTheme.accent,
            ink: plateLegible(ink, on: darkGround)
                ? Color(kiwiHex: ink)
                : SettingsTheme.plateInk,
            base: SettingsTheme.previewPlate
        )
    }
}

/// Writes a picture's plate paint into `schematicPalette`: the
/// picture's one writer, so every mark on it reads one verdict.
private struct PlatePaintWriter: ViewModifier {
    let settings: TilingSettings
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content.environment(
            \.schematicPalette,
            HomeCardPlate.palette(settings, in: scheme)
        )
    }
}

/// The plate itself, in the paint its writer resolved.
private struct DeskPlateGround<Plate: InsettableShape>: ViewModifier {
    let shape: Plate
    let edged: Bool
    @Environment(\.schematicPalette) private var palette

    func body(content: Content) -> some View {
        content
            .background(
                shape.fill(palette?.base ?? SettingsTheme.previewPlate)
            )
            .overlay {
                if edged {
                    shape.strokeBorder(
                        palette?.edge ?? SettingsTheme.planeRing,
                        lineWidth: 1
                    )
                }
            }
    }
}

extension View {
    /// Resolves the plate paint for `settings` (#2859) without
    /// drawing a plate — for a picture whose plates sit inside.
    func platePaint(_ settings: TilingSettings) -> some View {
        modifier(PlatePaintWriter(settings: settings))
    }

    /// Draws the picture on its plate, `shape`, in the paint
    /// resolved for `settings` (#2859); `edged` strokes the
    /// plate's inset edge over it.
    func deskPlate(
        _ settings: TilingSettings,
        in shape: some InsettableShape,
        edged: Bool = true
    ) -> some View {
        modifier(DeskPlateGround(shape: shape, edged: edged))
            .platePaint(settings)
    }
}
