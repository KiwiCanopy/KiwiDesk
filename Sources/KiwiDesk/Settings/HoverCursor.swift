import SwiftUI

/// Hover affordance applying pointing-hand cursor and color lift.
/// Cursor via `set()`, never push/pop: both call sites can leave
/// the hierarchy mid-hover and a removed view never delivers the
/// balancing `onHover(false)`; `onDisappear` restores the arrow.
private struct LinkHover: ViewModifier {
    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    func body(content: Content) -> some View {
        content
            .foregroundStyle(
                hovering
                    ? AnyShapeStyle(.primary)
                    : AnyShapeStyle(.secondary)
            )
            // Color lift is preserved; fade respects reduceMotion (#1069).
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.12),
                value: hovering
            )
            .onHover { inside in
                hovering = inside
                (inside ? NSCursor.pointingHand : .arrow)
                    .set()
            }
            .onDisappear {
                if hovering { NSCursor.arrow.set() }
            }
    }
}

/// Pointing-hand cursor on hover without color lift — same `set()`
/// + `onDisappear` discipline as `LinkHover`.
private struct PointingHandCursor: ViewModifier {
    @State private var hovering = false

    func body(content: Content) -> some View {
        content
            .onHover { inside in
                hovering = inside
                (inside ? NSCursor.pointingHand : .arrow).set()
            }
            .onDisappear {
                if hovering { NSCursor.arrow.set() }
            }
    }
}

extension View {
    /// Marks a link-like control: pointing-hand cursor and a
    /// color lift on hover say "this is clickable".
    func linkHover() -> some View {
        modifier(LinkHover())
    }

    /// Pointing-hand cursor only (no color lift), for clickable
    /// non-text controls like the color swatch.
    func pointingHandCursor() -> some View {
        modifier(PointingHandCursor())
    }
}
