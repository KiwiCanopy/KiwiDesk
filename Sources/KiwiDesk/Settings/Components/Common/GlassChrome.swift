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
    /// `enabled` is the #1307 switch's third leaf. Off takes the
    /// SAME `.regularMaterial` the pre-26 branch already draws,
    /// which `docs/design-decisions.md` rules to be today's
    /// design — so the off state is a shipped one rather than a
    /// new surface to design.
    func glassChrome(
        in shape: some Shape,
        enabled: Bool
    ) -> some View {
        glassGround(in: shape, enabled: enabled).clipShape(shape)
    }

    @ViewBuilder
    private func glassGround(
        in shape: some Shape,
        enabled: Bool
    ) -> some View {
        if #available(macOS 26, *), enabled {
            glassEffect(.regular, in: shape)
        } else {
            background(.regularMaterial)
        }
    }
}
