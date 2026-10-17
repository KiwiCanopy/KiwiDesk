import KiwiDeskCore
import SwiftUI

/// One picture in the shut card's strip: at rest on its key frame,
/// looping while hovered (never under Reduce Motion), its gesture's
/// sentence as the tooltip, half-faded where the gesture is off —
/// faded, not `GreyOut`, whose `.disabled` would refuse the click
/// that lands on the entry explaining why.
struct GestureStripPlate: View {
    let item: GestureItem
    let settings: TilingSettings
    let gestures: ScrollGestureBase
    let onLand: (GestureItem) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false
    @State private var phase: CGFloat = 0

    var body: some View {
        // A new identity per moving state ends a looping animation
        // with the view that ran it (`GestureEntry`).
        GesturePlate {
            item.picture(t: hovering ? phase : 1, gestures: gestures)
        }
        .id(hovering)
        .opacity(item.isOff(settings, gestures) ? 0.5 : 1)
        .contentShape(Rectangle())
        .onTapGesture { onLand(item) }
        .onHover(perform: hover)
        .help(item.sentence(settings))
    }

    /// Restarts the gesture from its first frame, then loops it.
    private func hover(_ inside: Bool) {
        hovering = inside && !reduceMotion
        phase = 0
        guard hovering else { return }
        DispatchQueue.main.async {
            guard hovering else { return }
            withAnimation(
                reduceMotion
                    ? nil
                    : item.pace.animation.repeatForever(
                        autoreverses: false
                    )
            ) {
                phase = 1
            }
        }
    }
}
