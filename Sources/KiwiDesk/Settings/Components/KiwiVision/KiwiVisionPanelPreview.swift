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

    /// What the picture draws: the selected chip's look over the
    /// draft's lenses, through the one resolver (`VisionLook`).
    private var look: VisionLook {
        var settings = model.appWide
        settings.visionLenses = model.draftLenses
        return settings.look(
            lens: model.nav.kiwiVisionLensSelection(in: model.draftLenses)
        )
    }

    var body: some View {
        let _ = reduceTransparency
        let look = look
        let dim = look.dim
        let blurs = model.core.kiwiVisionDrawsBlur(for: look)
        let effect = KiwiVisionEffect(
            dims: VisionPlateDim.opacity(forDim: dim / 100) > 0,
            blurs: blurs,
            windowsOnly: look.clearWallpaper,
            clearApp: look.clearApp
        )
        VStack(alignment: .leading, spacing: 8) {
            KiwiVisionScene(
                dimPercent: dim,
                blurs: blurs,
                windowsOnly: look.clearWallpaper,
                clearApp: look.clearApp,
                darkWindows: darkWindows,
                settings: model.config.settings
            )
            .accessibilityElement()
            .accessibilityLabel(effect.spoken(dimPercent: dim))
            Text(caption(effect))
                .font(.caption)
                .foregroundStyle(SettingsTheme.ink3)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityHidden(true)
        }
        .onAppear(perform: readAppearance)
        .onChange(of: look.appearance) { readAppearance() }
        .onChange(of: model.core.kiwiVisionIsOn) { readAppearance() }
        .onReceive(
            DistributedNotificationCenter.default().publisher(
                for: Notification.Name(
                    "AppleInterfaceThemeChangedNotification"
                )
            )
        ) { _ in readAppearance() }
    }

    /// A lens's picture names what it keeps clear (ruling 29).
    private func caption(_ effect: KiwiVisionEffect) -> String {
        guard let lens = look.lens else { return effect.caption }
        return KiwiVisionLensWords.panelCaption(
            lens.name,
            apps: lens.apps.map(KeybindingCatalog.displayName(forBundleID:))
        )
    }

    private func readAppearance() {
        darkWindows = model.core.kiwiVisionShowsDark(for: look)
    }
}
