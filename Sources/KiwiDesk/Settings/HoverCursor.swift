import SwiftUI

/// Link-like hover affordance for controls that don't look
/// like buttons (the make-default link, the rename pencil):
/// the pointing-hand cursor plus a secondary→primary color
/// lift while the mouse is over the view.
private struct LinkHover: ViewModifier {
    @State private var hovering = false

    func body(content: Content) -> some View {
        content
            .foregroundStyle(
                hovering
                    ? AnyShapeStyle(.primary)
                    : AnyShapeStyle(.secondary)
            )
            .animation(
                .easeOut(duration: 0.12),
                value: hovering
            )
            .onHover { inside in
                hovering = inside
                if inside {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
    }
}

extension View {
    /// Marks a link-like control: pointing-hand cursor and a
    /// color lift on hover say "this is clickable".
    func linkHover() -> some View {
        modifier(LinkHover())
    }
}
