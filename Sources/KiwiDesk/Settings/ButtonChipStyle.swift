import AppKit
import SwiftUI

/// The bordered action button's face (#2377): the button-chip tier
/// — `chipRest`, `chipHover` under the pointer, `chipPressed` while
/// pressed — under an edge no state moves, sized by the control
/// size the way the system bezel was (`ChipFace`). No animation;
/// a disabled button keeps its shape, drops its ink and stops
/// reacting.
struct ButtonChipStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        ChipFace(configuration: configuration, popUp: false)
    }

    /// The pointer's fill — the one ladder the jump chip shares.
    static func fill(pressed: Bool, hovered: Bool) -> Color {
        if pressed { return SettingsTheme.chipPressed }
        return hovered ? SettingsTheme.chipHover : SettingsTheme.chipRest
    }

    /// The system font and the bezel's room per control size —
    /// shared with `PopUpTriggerStyle`, so the two read one height.
    static func metrics(for controlSize: ControlSize) -> Metrics {
        switch controlSize {
        case .mini:
            return Metrics(
                font: 9,
                horizontal: 6,
                vertical: 2,
                radius: 4
            )
        case .small:
            return Metrics(
                font: 11,
                horizontal: 8,
                vertical: 3,
                radius: 5
            )
        case .large, .extraLarge:
            return Metrics(
                font: 13,
                horizontal: 14,
                vertical: 6,
                radius: 8
            )
        default:
            return Metrics(
                font: 13,
                horizontal: 10,
                vertical: 4,
                radius: 6
            )
        }
    }

    struct Metrics {
        let font: CGFloat
        let horizontal: CGFloat
        let vertical: CGFloat
        let radius: CGFloat
    }
}
