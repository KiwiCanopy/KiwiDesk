import SwiftUI

/// Fades what marks a tile's selection in and out (#3042). Under Reduce
/// Motion the mark arrives rather than fades.
private struct SelectionFade: ViewModifier {
    let selected: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.animation(
            reduceMotion ? nil : .easeOut(duration: 0.12),
            value: selected
        )
    }
}

extension View {
    /// Animates a change of `selected` inside this view.
    func selectionFade(_ selected: Bool) -> some View {
        modifier(SelectionFade(selected: selected))
    }
}

/// A selected surface's stroke, on a layer of its own over the surface's
/// rest and hover stroke, so it fades rather than snaps: a colour swap
/// through `AnyShapeStyle` may not interpolate.
struct SelectionStroke<S: InsettableShape, Style: ShapeStyle>: View {
    let selected: Bool
    let shape: S
    let style: Style
    let lineWidth: CGFloat

    var body: some View {
        shape
            .strokeBorder(style, lineWidth: lineWidth)
            .opacity(selected ? 1 : 0)
            .selectionFade(selected)
            .allowsHitTesting(false)
    }
}
