import KiwiDeskCore
import SwiftUI

/// KiwiHub's and the cue plates' ground (#2569): their Liquid Glass
/// leaf, and the shelf whose Fill they wear while "Tint KiwiHub and
/// plates" is on — on `.clear` glass where glass draws, flat over
/// the fallback material where it does not; frosted `.regular`
/// glass or the bare material without.
struct PanelGlass: Equatable {
    /// The Liquid Glass switch's leaf the surface follows.
    var enabled: Bool
    /// The shelf, while the surface wears its Fill.
    var shelf: KiwiShelf?

    /// The glass `settings` gives KiwiHub and the plates, which
    /// share KiwiHub's leaf (#2524); Reduce transparency lands
    /// live, in `ground(reduceTransparency:)`.
    init(settings: TilingSettings) {
        enabled = settings.shortcutPanelLiquidGlass
        shelf = settings.kiwishelf.panelsWearFill ? settings.kiwishelf : nil
    }

    private init(enabled: Bool, shelf: KiwiShelf?) {
        self.enabled = enabled
        self.shelf = shelf
    }

    /// Plain frosted glass on, before any settings are read.
    static let untinted = PanelGlass(enabled: true, shelf: nil)

    /// Whether the surface's glass may draw on this macOS, before
    /// Reduce transparency.
    private var drawable: Bool { enabled && GlassChromeVariant.drawable }

    /// What the surface draws on: Core's one answer, handed the
    /// leaf as drawn under the live Reduce transparency.
    func ground(reduceTransparency: Bool) -> PanelGround {
        shelf?.panelGround(
            glassDrawn: drawable && !reduceTransparency,
            reduceTransparency: reduceTransparency
        ) ?? .untinted
    }

    var variant: GlassChromeVariant { shelf == nil ? .regular : .clear }

    /// Whether the panel wears the key-window rim: glass's finish,
    /// so never over the material.
    var wearsActiveLook: Bool { shelf != nil && drawable }
}

extension View {
    /// `glassChrome(in:)` as KiwiHub and the cue plates draw it:
    /// on glass the Fill faded top to bottom, floored for their inks
    /// under Increase Contrast read here; over the fallback the Fill
    /// flat; and the look's three inks as the hierarchical styles
    /// beneath either.
    func panelGlassChrome(
        in shape: some Shape,
        glass: PanelGlass,
        fallback: AnyShapeStyle
    ) -> some View {
        modifier(
            PanelGlassChrome(shape: shape, glass: glass, fallback: fallback)
        )
    }
}

private struct PanelGlassChrome<S: Shape>: ViewModifier {
    @Environment(\.colorSchemeContrast) private var contrast
    /// `glassChrome` gates its branch on the same value; this reader
    /// moves the Fill from the glass onto the material with it.
    @Environment(\.accessibilityReduceTransparency)
    private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    let shape: S
    let glass: PanelGlass
    let fallback: AnyShapeStyle

    private var increased: Bool { contrast == .increased }

    private var ground: PanelGround {
        glass.ground(reduceTransparency: reduceTransparency)
    }

    /// The look's three inks while the panel wears the Fill; the
    /// untinted panel keeps SwiftUI's own hierarchy, untouched.
    @ViewBuilder private func inked(
        _ content: Content,
        _ ink: PanelInk?
    ) -> some View {
        if let ink {
            content.foregroundStyle(
                Color(kiwiHex: ink.primary),
                Color(kiwiHex: ink.secondary),
                Color(kiwiHex: ink.tertiary)
            )
        } else {
            content
        }
    }

    func body(content: Content) -> some View {
        let ground = ground
        let frost = ground.frost
        // The one place Increase Contrast becomes the panel's inks.
        let ink = glass.shelf?.panelInk(increaseContrast: increased)
        // One mint: the glass and KiwiHub's fills fade alike. Over
        // the material the Fill is flat, so nothing fades.
        let tint =
            ground == .glass
            ? glass.shelf.flatMap {
                GlassTint.paint(
                    $0.panelGlassFill(increaseContrast: increased),
                    edge: .top
                )
            } : nil
        inked(content, ink)
            .environment(
                \.kiwiHubPaint,
                KiwiHubPaint.of(
                    glass,
                    ink: ink,
                    tint: tint,
                    increaseContrast: increased
                )
            )
            .background { frost.map { shape.fill($0.color) } }
            .glassChrome(
                in: shape,
                enabled: glass.enabled,
                variant: glass.variant,
                tint: tint,
                fallback: fallback
            )
            // The frost and its content take the Fill's scheme, as
            // glass does from its paint.
            .environment(\.colorScheme, frost?.scheme ?? colorScheme)
    }
}

extension FrostFill {
    /// The Fill as SwiftUI draws it over the material.
    var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }

    /// The scheme the Fill pins on its frost.
    var scheme: ColorScheme { pin == .dark ? .dark : .light }
}
