import KiwiDeskCore
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
    /// read or a Fill carries it. `tint` is that Fill, minted by
    /// `GlassTint.paint` and drawn on the glass beneath the content
    /// (#2569) — nil for an untinted surface.
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
        tint: GlassPaint?,
        fallback: AnyShapeStyle
    ) -> some View {
        modifier(
            GlassChrome(
                shape: shape,
                enabled: enabled,
                variant: variant,
                tint: tint,
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
        tint: GlassPaint?,
        colorScheme: ColorScheme,
        fallback: AnyShapeStyle
    ) -> some View {
        if #available(macOS 26, *), enabled {
            // The Fill is the view's own ground, so the glass draws
            // beneath it and the content above it (#2569).
            background { tint.map { shape.fill($0.gradient) } }
                .glassEffect(variant.glass, in: shape)
                .environment(\.colorScheme, tint?.scheme ?? colorScheme)
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

    @Environment(\.colorScheme) private var colorScheme

    let shape: S
    let enabled: Bool
    let variant: GlassChromeVariant
    let tint: GlassPaint?
    let fallback: AnyShapeStyle

    func body(content: Content) -> some View {
        content.glassGround(
            in: shape,
            enabled: enabled && !reduceTransparency,
            variant: variant,
            tint: tint,
            colorScheme: colorScheme,
            fallback: fallback
        )
    }
}

/// The glass finish, a legibility decision per surface (gui.md):
/// `.regular` under dense text, `.clear` where nothing is read or
/// a Fill carries the text (#2569).
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

extension GlassPaint {
    /// The scheme the Fill pins, nil where it pins none.
    var scheme: ColorScheme? {
        switch pin {
        case .dark?: .dark
        case .light?: .light
        case nil: nil
        }
    }

    /// The Fill's fade as SwiftUI draws it.
    var gradient: LinearGradient {
        LinearGradient(
            colors: [anchorAlpha, farAlpha].map {
                Color(.sRGB, red: red, green: green, blue: blue, opacity: $0)
            },
            startPoint: UnitPoint(x: start.x, y: start.y),
            endPoint: UnitPoint(x: end.x, y: end.y)
        )
    }
}
