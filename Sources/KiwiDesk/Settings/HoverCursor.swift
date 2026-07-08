import SwiftUI

/// Link-like hover affordance for controls that don't look
/// like buttons (the make-default link, the rename pencil):
/// the pointing-hand cursor plus a secondary→primary color
/// lift while the mouse is over the view. Cursor changes use
/// `set()`, never push/pop: both call sites can remove
/// themselves from the hierarchy mid-hover (make-default
/// drops its own link, rename rebuilds the row identity) and
/// a removed view never delivers the balancing
/// `onHover(false)` — the imbalance the spaces drag handle
/// fixed the same way. `onDisappear` restores the arrow when
/// the view vanishes under the pointer.
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
                (inside ? NSCursor.pointingHand : .arrow)
                    .set()
            }
            .onDisappear {
                if hovering { NSCursor.arrow.set() }
            }
    }
}

/// Pointing-hand cursor on hover *without* the link color
/// lift — for clickable controls that aren't text (the color
/// swatch). Same `set()` + `onDisappear` discipline as
/// `LinkHover`, so a view removed mid-hover restores the arrow.
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
