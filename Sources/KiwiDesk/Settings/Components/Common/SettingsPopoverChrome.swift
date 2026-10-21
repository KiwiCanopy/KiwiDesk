import SwiftUI

extension View {
    /// The one surface a Settings popover wears (#2503): untinted
    /// Liquid Glass, the popover material under Reduce transparency
    /// and below macOS 26 (#2399, #1295). Applied to its content.
    func settingsPopoverChrome() -> some View {
        presentationBackground {
            Color.clear.glassChrome(
                in: Rectangle(),
                enabled: true,
                variant: .regular,
                fallback: AnyShapeStyle(.regularMaterial)
            )
        }
    }
}
