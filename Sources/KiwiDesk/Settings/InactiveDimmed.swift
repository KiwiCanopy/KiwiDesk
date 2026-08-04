import SwiftUI

/// Fades hand-built chrome while the window is inactive — the
/// treatment System Settings gives its colored sidebar icons: a
/// plain alpha fade that keeps the hue, never a desaturate
/// (settled by eye — grayscale reads as "disabled"). Survived
/// the sidebar it was built for (#297 → #678 turn 9): the
/// search field and the Home cards' icon tiles still dim by it.
/// Deliberately keyed to `.inactive` only — `.active` (window
/// not key, app still active, e.g. while the shared color panel
/// is up) must not dim.
struct InactiveDimmed: ViewModifier {
    /// The one fade shared by every dimmed element — they key
    /// off the same state change and must stay in lockstep.
    static let fade = Animation.easeInOut(duration: 0.15)

    @Environment(\.controlActiveState) private var activeState

    func body(content: Content) -> some View {
        content
            .opacity(activeState == .inactive ? 0.5 : 1)
            .animation(Self.fade, value: activeState)
    }
}

extension View {
    func inactiveDimmed() -> some View {
        modifier(InactiveDimmed())
    }
}
