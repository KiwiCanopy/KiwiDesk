import SwiftUI

extension EnvironmentValues {
    /// What a Desktops refusal swells now (#3170), read by the line
    /// and its icons.
    @Entry var desktopsSwell: DesktopsSwell?
}

/// A refused Desktops thing swells once, as a refused Windows row's
/// reason does (#3170, `JumpRefusalView`).
struct DesktopsSwellEffect: ViewModifier {
    let pulsing: Bool
    let anchor: UnitPoint

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(pulsing ? JumpRefusalView.swell : 1, anchor: anchor)
            .animation(
                reduceMotion
                    ? nil : .spring(response: 0.2, dampingFraction: 0.6),
                value: pulsing
            )
    }
}

extension View {
    func desktopsSwell(_ pulsing: Bool, anchor: UnitPoint) -> some View {
        modifier(DesktopsSwellEffect(pulsing: pulsing, anchor: anchor))
    }
}
