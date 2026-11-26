import SwiftUI

/// The incoming backdrop wiped in from the side the next look comes
/// from, its soft edge 30 % of the screen wide (owner, prototype
/// 2026-11-26). #3478's picture takes the same wipe, decoded once at
/// screen size, never redrawn full size per frame.
struct LookPickerSwapIn: ViewModifier, Animatable {
    var progress: CGFloat
    /// +1 for a step rightward, -1 leftward.
    let side: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let lead = -Self.soft + progress * (1 + Self.soft * 2)
        let opaque = max(0, min(1, lead - Self.soft))
        let edge = max(opaque + 0.0001, min(1, lead))
        content.mask(
            LinearGradient(
                stops: [
                    .init(color: .black, location: opaque),
                    .init(color: .clear, location: edge),
                ],
                startPoint: side > 0 ? .trailing : .leading,
                endPoint: side > 0 ? .leading : .trailing
            )
        )
    }

    /// The soft edge's width, a share of the screen's.
    static let soft: CGFloat = 0.3
}
