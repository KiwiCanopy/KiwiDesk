import KiwiDeskCore
import SwiftUI

/// KiwiHub's and the cue plates' glass (#2569): their Liquid Glass
/// leaf, and the shelf whose Fill they wear while "Tint KiwiHub and
/// plates" is on — `.clear` with the Fill then, today's frosted
/// `.regular` without.
struct PanelGlass: Equatable {
    /// The Liquid Glass switch's leaf the surface follows.
    var enabled: Bool
    /// The shelf, while the surface wears its Fill.
    var shelf: KiwiShelf?

    /// The glass `settings` gives KiwiHub and the plates, which
    /// share KiwiHub's leaf (#2524).
    init(settings: TilingSettings) {
        enabled = settings.shortcutPanelLiquidGlass
        // No colour leaves nothing to wear: the untinted panel.
        let shelf = settings.kiwishelf
        self.shelf = shelf.tintHubAndPlates && shelf.hasFill ? shelf : nil
    }

    init(enabled: Bool, shelf: KiwiShelf?) {
        self.enabled = enabled
        self.shelf = shelf
    }

    var variant: GlassChromeVariant { shelf == nil ? .regular : .clear }

    /// Whether the panel wears the key-window rim.
    var wearsActiveLook: Bool { shelf != nil }
}

extension View {
    /// `glassChrome(in:)` as KiwiHub and the cue plates draw it:
    /// the Fill faded top to bottom, floored for their inks under
    /// Increase Contrast read here, and the look's three inks as the
    /// hierarchical styles beneath it.
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

    let shape: S
    let glass: PanelGlass
    let fallback: AnyShapeStyle

    private var increased: Bool { contrast == .increased }

    func body(content: Content) -> some View {
        content
            .foregroundStyle(
                glass.shelf.map {
                    Color(
                        kiwiHex: $0.panelInk(increaseContrast: increased)
                            .primary
                    )
                }
                    ?? Color.primary,
                glass.shelf.map {
                    Color(
                        kiwiHex: $0.panelInk(increaseContrast: increased)
                            .secondary
                    )
                }
                    ?? Color.secondary,
                glass.shelf.map {
                    Color(
                        kiwiHex: $0.panelInk(increaseContrast: increased)
                            .tertiary
                    )
                }
                    ?? Color(nsColor: .tertiaryLabelColor)
            )
            .glassChrome(
                in: shape,
                enabled: glass.enabled,
                variant: glass.variant,
                tint: glass.shelf.flatMap {
                    GlassTint.paint(
                        $0.panelGlassFill(
                            increaseContrast: contrast == .increased
                        ),
                        edge: .top
                    )
                },
                fallback: fallback
            )
    }
}
