import SwiftUI

/// View modifier that dims chrome elements when window is inactive
/// (#297, #678).
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
