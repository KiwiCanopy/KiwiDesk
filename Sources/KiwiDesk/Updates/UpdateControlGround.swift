import SwiftUI

extension View {
    /// The opaque ground a control on the update window's glass
    /// sits on (#3666): the glass adapts to the backdrop, so a
    /// fixed ink on a translucent face sinks wherever it greys.
    /// On `card` the control's face and ink are the ones
    /// `SettingsThemeContrastTests` measures there (gui.md).
    func updateControlGround<S: Shape>(_ shape: S) -> some View {
        background { shape.fill(SettingsTheme.card) }
    }

    /// An action button's ground, in its chip's own shape at the
    /// environment's control size. Follows `settingsActionButton()`.
    func updateActionGround() -> some View {
        modifier(UpdateActionGround())
    }
}

private struct UpdateActionGround: ViewModifier {
    @Environment(\.controlSize) private var controlSize

    func body(content: Content) -> some View {
        content.updateControlGround(
            ButtonChipStyle.bezel(for: controlSize)
        )
    }
}
