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
    /// share KiwiHub's leaf (#2524), on a platform that draws glass;
    /// Reduce transparency lands live, in `drawn(reduceTransparency:)`.
    init(settings: TilingSettings) {
        enabled = settings.shortcutPanelLiquidGlass
        let drawable = enabled && GlassChromeVariant.drawable
        shelf =
            settings.panelsWearFill(glassDrawn: drawable)
            ? settings.kiwishelf : nil
    }

    private init(enabled: Bool, shelf: KiwiShelf?) {
        self.enabled = enabled
        self.shelf = shelf
    }

    /// Plain frosted glass on, before any settings are read.
    static let untinted = PanelGlass(enabled: true, shelf: nil)

    /// The glass as drawn: glass off or Reduce transparency draws
    /// the fallback, which wears no Fill and so none of its inks.
    func drawn(reduceTransparency: Bool) -> PanelGlass {
        enabled && !reduceTransparency
            ? self : PanelGlass(enabled: enabled, shelf: nil)
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
    /// `glassChrome` gates its branch on the same value; this reader
    /// takes the Fill's inks and KiwiHub's paint down with it.
    @Environment(\.accessibilityReduceTransparency)
    private var reduceTransparency

    let shape: S
    let glass: PanelGlass
    let fallback: AnyShapeStyle

    private var increased: Bool { contrast == .increased }

    private var drawn: PanelGlass {
        glass.drawn(reduceTransparency: reduceTransparency)
    }

    /// The look's three inks while the panel wears the Fill; the
    /// untinted panel keeps SwiftUI's own hierarchy, untouched.
    @ViewBuilder private func inked(_ content: Content) -> some View {
        if let shelf = drawn.shelf {
            let ink = shelf.panelInk(increaseContrast: increased)
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
        inked(content)
            .environment(\.kiwiHubPaint, KiwiHubPaint.of(drawn))
            .glassChrome(
                in: shape,
                enabled: drawn.enabled,
                variant: drawn.variant,
                tint: drawn.shelf.flatMap {
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
