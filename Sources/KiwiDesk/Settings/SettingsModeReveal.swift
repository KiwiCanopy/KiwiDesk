import SwiftUI

/// Mode reveal accent wash modifier for advanced settings sections
/// (`SettingsTheme.containerStrokeModeGated`, `SearchRevealFlash`, #760).
private struct ModeRevealActiveKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Indicates whether settings mode reveal wash is active.
    var settingsModeReveal: Bool {
        get { self[ModeRevealActiveKey.self] }
        set { self[ModeRevealActiveKey.self] = newValue }
    }
}

/// Paints transient accent background wash behind mode-gated section headers.
private struct ModeRevealWash: ViewModifier {
    let gated: Bool
    @Environment(\.settingsModeReveal) private var active
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion
    private var washed: Bool { gated && active }

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(
                    cornerRadius: SettingsReveal.cornerRadius
                )
                .fill(
                    SettingsTheme.accent.opacity(
                        washed ? SettingsReveal.peakOpacity : 0
                    )
                )
                .padding(-SettingsReveal.bleed)
            }
            .animation(fadeOut, value: washed)
    }

    private var fadeOut: Animation? {
        guard !reduceMotion, !washed else { return nil }
        return .easeOut(duration: SettingsReveal.fade)
    }
}

extension View {
    /// Applies transient highlight wash when switching settings modes (#760).
    func modeRevealWash(_ gated: Bool) -> some View {
        modifier(ModeRevealWash(gated: gated))
    }
}
