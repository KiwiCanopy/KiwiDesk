import SwiftUI

extension View {
    /// Draws `shape` as this view's chrome — Liquid Glass on
    /// macOS 26, `fallback` below — and clips to it.
    ///
    /// The one home for this tree's `#available` branch, and the
    /// clip sits OUTSIDE it: `glassEffect(_:in:)` draws in a
    /// shape without clipping to it, so a per-branch clip makes
    /// the two halves disagree on an axis no caller can see
    /// (`GlassChromeSeamTests`).
    ///
    /// `variant` is each surface's legibility decision (gui.md):
    /// `.regular` under dense text, `.clear` where nothing is
    /// read. Untinted by ruling rather than by capability
    /// (`docs/design-decisions.md` ▸ the shortcuts panel, #1295).
    /// `enabled` is the caller's WHETHER — a Liquid Glass switch
    /// leaf, or a state such as the slider knob's drag (exempt
    /// from the switch by ruling, #1527). `fallback` is the
    /// surface's shipped design, drawn when `enabled` is off,
    /// below macOS 26, and under Reduce transparency, read live
    /// from the environment (#1374).
    func glassChrome(
        in shape: some Shape,
        enabled: Bool,
        variant: GlassChromeVariant,
        fallback: AnyShapeStyle
    ) -> some View {
        modifier(
            GlassChrome(
                shape: shape,
                enabled: enabled,
                variant: variant,
                fallback: fallback
            )
        )
        .clipShape(shape)
    }

    @ViewBuilder
    fileprivate func glassGround(
        in shape: some Shape,
        enabled: Bool,
        variant: GlassChromeVariant,
        fallback: AnyShapeStyle
    ) -> some View {
        if #available(macOS 26, *), enabled {
            glassEffect(variant.glass, in: shape)
        } else {
            background(fallback)
        }
    }
}

/// The one reader of Reduce transparency in this tree (#1374): a
/// modifier, because an environment value is read from a view
/// body rather than from a `View` extension's function.
private struct GlassChrome<S: Shape>: ViewModifier {
    @Environment(\.accessibilityReduceTransparency)
    private var reduceTransparency

    let shape: S
    let enabled: Bool
    let variant: GlassChromeVariant
    let fallback: AnyShapeStyle

    func body(content: Content) -> some View {
        content.glassGround(
            in: shape,
            enabled: enabled && !reduceTransparency,
            variant: variant,
            fallback: fallback
        )
    }
}

/// The glass finish, a legibility decision per surface (gui.md):
/// `.regular` under dense text, `.clear` where nothing is read.
enum GlassChromeVariant {
    case regular
    case clear

    /// Whether this macOS can draw glass at all — the platform
    /// half of the branch, for a caller that must know which
    /// side it is on.
    static var drawable: Bool {
        if #available(macOS 26, *) { true } else { false }
    }

    @available(macOS 26, *)
    fileprivate var glass: Glass {
        switch self {
        case .regular: .regular
        case .clear: .clear
        }
    }
}
