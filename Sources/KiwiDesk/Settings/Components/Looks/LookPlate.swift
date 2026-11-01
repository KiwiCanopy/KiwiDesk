import KiwiDeskCore
import SwiftUI

/// A look's picture (#1740): a desk in the look — its bars with
/// Finder, Safari and Mail, three windows at its gaps, the focused
/// one in its ring — on its own shelf colour. The look tile,
/// Simple's Look line, onboarding and `kiwidesk preview` draw it;
/// headless, per gui.md ▸ The CLI's local verbs.
struct LookPlate: View {
    /// The draft with the look painted on.
    let settings: TilingSettings
    let spaceLabels: [SpaceGlyph]
    /// Where the picture is shown: a tile, or the gallery's PNG.
    var size = Size.tile

    /// The gallery draws on a taller canvas, so its bars take a
    /// desk's share at their font's own size, and alone stands the
    /// pocket, which a tile has no room for.
    enum Size {
        case tile, gallery

        @MainActor var height: CGFloat {
            PaletteSceneThumbnail.baseHeight * desk
        }
        /// The desk's own geometry — gaps, the ring, the pocket —
        /// grows with the canvas; the bars keep their font's size.
        var desk: CGFloat { self == .tile ? 1 : 2 }
        var drawsPocket: Bool { self == .gallery }
    }

    var body: some View {
        ZStack {
            ground
            HomeCardBarsTile(
                settings: settings,
                pocketStands: pocketRest == .section,
                spaceCount: spaceLabels.count,
                scale: Self.barScale,
                spaceLabels: spaceLabels,
                wellContent: AnyView(LookDesk(plate: self)),
                appArt: Self.appArt(settings.kiwishelf.iconSource),
                drawsChrome: false
            )
            .padding(2)
            .environment(
                \.schematicPalette,
                HomeCardPlate.darkPalette(settings)
            )
            if pocketRest == .mark {
                lonePocket
            }
        }
        .clipShape(
            RoundedRectangle(
                cornerRadius: PaletteSceneThumbnail.plateRadius
                    * size.height / PaletteSceneThumbnail.baseHeight
            )
        )
        .frame(height: size.height)
        .frame(maxWidth: .infinity)
        // Hidden from VoiceOver, never from the pointer: the plate is
        // most of a card's Button label, so a click on it is the click.
        .accessibilityHidden(true)
    }

    /// The bars' scale on the picture: smaller than the Bars
    /// card's, so both bars and the pocket fit a tile's width.
    static let barScale: CGFloat = 0.62

    /// The look's own shelf colour over a night, darkened a step,
    /// a faint haze of the focus colour from the top.
    private var ground: some View {
        ZStack {
            SettingsTheme.lookGround
            Color(kiwiHex: settings.kiwishelf.fillColor)
            SettingsTheme.lookGround.opacity(0.15)
            RadialGradient(
                colors: [
                    Color(kiwiHex: settings.borderStyle.focusedColor)
                        .opacity(0.3),
                    .clear,
                ],
                center: .top,
                startRadius: 0,
                endRadius: size.height * 0.9
            )
        }
    }

    /// The focused window's ring: the look's colour and sheen at
    /// its width through the shared remap (#786) and its corners;
    /// nothing while the draft draws no ring.
    func focusRing(_ shape: RoundedRectangle) -> some View {
        let border = settings.borderStyle
        return
            shape
            .strokeBorder(
                SheenPaint.style(
                    settings.borderStyle.focusedColor,
                    sheen: settings.borderStyle.sheen
                ),
                lineWidth: ringWidth
            )
            .opacity(border.enabled ? 1 : 0)
    }

    /// The ring's glow, drawn beneath the window so the paper
    /// covers what it casts inside.
    func focusGlow(_ shape: RoundedRectangle) -> some View {
        let border = settings.borderStyle
        return shape.fill(Color(kiwiHex: border.focusedColor))
            .shadow(
                color: Color(kiwiHex: border.focusedColor),
                radius: ringWidth * 1.5
            )
            .opacity(border.enabled && border.glow ? 1 : 0)
    }

    /// The ring's width on the picture, read through the one
    /// border remap.
    var ringWidth: CGFloat {
        BorderPreviewScale.width(
            settings.borderStyle.clampedWidth,
            to: 0.75...3
        ) * size.desk
    }
}
