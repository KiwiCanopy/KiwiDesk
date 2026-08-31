import SwiftUI

/// Dims hand-built chrome while the window is inactive (#297,
/// #678): a plain alpha fade that keeps the hue, never a
/// desaturate — grayscale reads as "disabled". Keyed to
/// `.inactive` ONLY: `.active` (window not key while the shared
/// color panel is up) must not dim.
struct InactiveDimmed: ViewModifier {
    /// Shared crossfade animation.
    static let fade = Animation.easeInOut(duration: 0.15)

    @Environment(\.controlActiveState) private var activeState
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(activeState == .inactive ? 0.5 : 1)
            // The dim itself stays — it is the affordance, and
            // the window really is inactive; only the crossfade
            // to it stands down (#989).
            .animation(
                reduceMotion ? nil : Self.fade,
                value: activeState
            )
    }
}

extension View {
    func inactiveDimmed() -> some View {
        modifier(InactiveDimmed())
    }
}
