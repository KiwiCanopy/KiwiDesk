import KiwiDeskCore
import SwiftUI

/// KiwiVision's side-panel picture (#2103): the drawn scene at the
/// running values, its caption, and one VoiceOver element. Redrawn
/// when macOS switches appearance, which the windows follow.
struct KiwiVisionPanelPreview: View {
    @ObservedObject var model: SettingsModel
    /// Read so a flip re-renders; the verdict stays Core's door.
    @Environment(\.accessibilityReduceTransparency)
    private var reduceTransparency
    /// The appearance the windows show, read once per change —
    /// it asks macOS's preferences — never per render.
    @State private var darkWindows = false

    var body: some View {
        let _ = reduceTransparency
        let dim = model.appWide.visionDim
        let blurs = model.core.kiwiVisionDrawsBlur
        let windowsOnly = model.appWide.visionClearWallpaper
        let effect = KiwiVisionEffect(
            dims: VisionPlateDim.opacity(forDim: dim / 100) > 0,
            blurs: blurs,
            windowsOnly: windowsOnly
        )
        VStack(alignment: .leading, spacing: 8) {
            KiwiVisionScene(
                dimPercent: dim,
                blurs: blurs,
                windowsOnly: windowsOnly,
                darkWindows: darkWindows,
                settings: model.config.settings
            )
            .accessibilityElement()
            .accessibilityLabel(effect.spoken(dimPercent: dim))
            Text(effect.caption)
                .font(.caption)
                .foregroundStyle(SettingsTheme.ink3)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityHidden(true)
        }
        .onAppear(perform: readAppearance)
        .onChange(of: model.appWide.visionAppearance) { readAppearance() }
        .onChange(of: model.core.kiwiVisionIsOn) { readAppearance() }
        .onReceive(
            DistributedNotificationCenter.default().publisher(
                for: Notification.Name(
                    "AppleInterfaceThemeChangedNotification"
                )
            )
        ) { _ in readAppearance() }
    }

    private func readAppearance() {
        darkWindows = model.core.kiwiVisionShowsDark
    }
}
