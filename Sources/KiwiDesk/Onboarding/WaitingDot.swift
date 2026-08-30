import SwiftUI

/// Animated pulsating indicator dot for in-flight tasks and waiting states
/// (#828).
struct WaitingDot: View {
    var ink: Color = SettingsTheme.warningInk

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathing = false

    private let size: CGFloat = 9

    var body: some View {
        Circle()
            .fill(ink)
            .frame(width: size, height: size)
            .opacity(opacity)
            .animation(pulse, value: breathing)
            .onAppear { breathing = true }
            .accessibilityHidden(true)
    }

    private var opacity: Double {
        guard !reduceMotion else { return 0.8 }
        return breathing ? 0.35 : 1
    }

    private var pulse: Animation? {
        guard !reduceMotion else { return nil }
        return .easeInOut(duration: 1.1).repeatForever(
            autoreverses: true
        )
    }
}
