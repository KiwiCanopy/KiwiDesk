import SwiftUI

/// A segment's button: `.plain` faded its label while pressed, which
/// read lighter than the hover; an unselected segment presses one
/// step darker than its hover lift instead, the chip ladder's
/// order (#2377).
struct SegmentPressStyle: ButtonStyle {
    let presses: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label.background(
            Capsule().fill(
                presses && configuration.isPressed
                    ? SettingsTheme.chipHover : .clear
            )
        )
    }
}
