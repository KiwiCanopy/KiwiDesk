import SwiftUI

/// A tile or card under the pointer rises on a shadow (#3042); its
/// edge is the surface's own stroke (`SettingsTheme.hoverEdge`). The
/// shadow falls from `shape`, so a transparent tile casts one and a
/// picture is never rasterized for it. The hit area stays at rest, so
/// a pointer at the bottom edge cannot leave and re-enter. Under
/// Reduce Motion the rise arrives rather than travels.
private struct HoverRise<S: Shape>: ViewModifier {
    let risen: Bool
    let shape: S
    @Environment(\.kiwiDeskReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .background {
                shape
                    .fill(SettingsTheme.card)
                    .shadow(
                        color: SettingsTheme.hoverRiseShadow,
                        radius: SettingsTheme.hoverShadowRadius,
                        y: SettingsTheme.hoverShadowDrop
                    )
                    .opacity(risen ? 1 : 0)
                    .allowsHitTesting(false)
            }
            .offset(y: risen ? -SettingsTheme.hoverRise : 0)
            .contentShape(shape)
            .animation(
                reduceMotion ? nil : HoverRiseTiming.animation,
                value: risen
            )
    }
}

/// The rise's pace, shared by a host moving something laid over a
/// risen tile with it (#3478's badge).
enum HoverRiseTiming {
    static let animation = Animation.easeOut(duration: 0.12)
}

extension View {
    /// Raises the view on a shadow cast from `shape` while `risen`.
    func hoverRise(_ risen: Bool, in shape: some Shape) -> some View {
        modifier(HoverRise(risen: risen, shape: shape))
    }
}
