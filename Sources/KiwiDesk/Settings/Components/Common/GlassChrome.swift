import SwiftUI

extension View {
    /// Draws `shape` as this view's chrome — Liquid Glass on
    /// macOS 26, `.regularMaterial` below — and clips to it.
    ///
    /// The one home for this tree's `#available` branch, and the
    /// clip sits OUTSIDE it: `glassEffect(_:in:)` draws in a
    /// shape without clipping to it, so a per-branch clip makes
    /// the two halves disagree on an axis no caller can see
    /// (`GlassChromeSeamTests`).
    ///
    /// `.regular` because this tree's glass carries dense text —
    /// NOT a default, and not the bars' `.clear`. Untinted by
    /// ruling rather than by capability. Both arguments, and the
    /// Reduce Transparency gap this does not answer, are in
    /// `docs/design-decisions.md` ▸ the reference panel (#1295).
    func glassChrome(in shape: some Shape) -> some View {
        glassGround(in: shape).clipShape(shape)
    }

    @ViewBuilder
    private func glassGround(in shape: some Shape) -> some View {
        if #available(macOS 26, *) {
            glassEffect(.regular, in: shape)
        } else {
            background(.regularMaterial)
        }
    }
}
