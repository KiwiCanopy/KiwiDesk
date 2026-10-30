import KiwiDeskCore
import SwiftUI

/// A look's picture (#1740): a desk in the look — its bars on
/// their edges with Finder, Safari and Mail in the App Bar, three
/// windows at its gaps, the focused one ringed in its colour,
/// sheen and glow — over a ground of its own shelf colour (owner,
/// 2026-10-30, overturning the neutral plate for this picture).
/// The shelf tile, Simple's Look line, onboarding and
/// `kiwidesk preview` draw it; it reads no `NSApp`, environment
/// object or live model, so `preview` renders it headless.
struct LookPlate: View {
    /// The draft with the look painted on.
    let settings: TilingSettings
    let spaceLabels: [SpaceGlyph]
    /// Whether the pocket mark stands on its edge: the gallery's
    /// picture alone, since a tile has no room for it (owner,
    /// 2026-10-30; #2678 keeps it off the card).
    var drawsPocket = false

    var body: some View {
        ZStack {
            ground
            HomeCardBarsTile(
                settings: settings,
                pocketStands: drawsPocket,
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
                HomeCardPlate.palette(settings)
            )
            if drawsPocket && !pocketOnABar {
                lonePocket
            }
        }
        .clipShape(
            RoundedRectangle(
                cornerRadius: PaletteSceneThumbnail.plateRadius
            )
        )
        .frame(height: PaletteSceneThumbnail.baseHeight)
        .frame(maxWidth: .infinity)
        // Hidden from VoiceOver, never from the pointer: the plate is
        // most of a card's Button label, so a click on it is the click.
        .accessibilityHidden(true)
    }

    /// Whether a bar sits on the pocket's edge, where the shelf's
    /// strip stands it; elsewhere it rests whole on its own edge.
    var pocketOnABar: Bool {
        settings.barEdges(space: .always, app: .always).contains {
            $0.edge == settings.kiwishelf.pocketEdge
        }
    }

    /// The pocket resting whole on an edge no bar sits on, at its
    /// Position along it, as the live pocket rests (#2784).
    private var lonePocket: some View {
        GeometryReader { plate in
            let shelf = settings.kiwishelf
            let side = Self.lonePocketSide
            let along = shelf.pocketPosition / 100
            let inset = side / 2 + 2
            let x: CGFloat =
                switch shelf.pocketEdge {
                case .left: inset
                case .right: plate.size.width - inset
                case .top, .bottom: plate.size.width * along
                }
            let y: CGFloat =
                switch shelf.pocketEdge {
                case .top: inset
                case .bottom: plate.size.height - inset
                case .left, .right: plate.size.height * along
                }
            Image(
                nsImage: PocketMark.mark.image(
                    size: side,
                    hex: settings.pocketStyle.color
                )
            )
            .position(x: x, y: y)
        }
    }

    /// The lone pocket's side on the plate.
    static let lonePocketSide = PaletteSceneThumbnail.baseHeight * 0.13

    /// The edge a lone pocket reserves its strip on, as the live
    /// one does (#2801); nil where it stands on a bar or not at all.
    var pocketReserve: AppBarEdge? {
        drawsPocket && !pocketOnABar ? settings.kiwishelf.pocketEdge : nil
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
                endRadius: PaletteSceneThumbnail.baseHeight * 0.9
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
        )
    }
}
