import KiwiDeskCore
import SwiftUI

/// KiwiVision's side-panel picture (#2103): the drawn scene at the
/// running values, its caption, and one VoiceOver element. Redrawn
/// when macOS switches appearance, which the windows follow.
struct KiwiVisionPanelPreview: View {
    @ObservedObject var model: SettingsModel
    /// Bumped by macOS's theme notification to redraw.
    @State private var themeTick = 0

    private var effect: KiwiVisionEffect {
        KiwiVisionEffect(
            dims: model.appWide.visionDim > 0,
            blurs: model.core.kiwiVisionDrawsBlur
        )
    }

    var body: some View {
        let _ = themeTick
        VStack(alignment: .leading, spacing: 8) {
            KiwiVisionScene(
                dimPercent: model.appWide.visionDim,
                blurs: model.core.kiwiVisionDrawsBlur,
                darkWindows: model.core.kiwiVisionShowsDark,
                settings: model.config.settings
            )
            .accessibilityElement()
            .accessibilityLabel(
                effect.spoken(dimPercent: model.appWide.visionDim)
            )
            Text(effect.caption)
                .font(.caption)
                .foregroundStyle(SettingsTheme.ink3)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityHidden(true)
        }
        .onReceive(
            DistributedNotificationCenter.default().publisher(
                for: Notification.Name(
                    "AppleInterfaceThemeChangedNotification"
                )
            )
        ) { _ in themeTick += 1 }
    }
}

/// What the picture shows at the running values; the caption and
/// the spoken label read the same two facts.
@MainActor
struct KiwiVisionEffect: Equatable {
    var dims: Bool
    var blurs: Bool

    /// Each state's whole caption is one key, so no locale has
    /// to join two sentences.
    var caption: String {
        switch (dims, blurs) {
        case (true, true):
            return L(
                "kiwivision.preview.caption.dim_blur",
                "Everything but the focused window is dimmed and "
                    + "blurred. Focus another window and it becomes "
                    + "the clear one."
            )
        case (true, false):
            return L(
                "kiwivision.preview.caption.dim",
                "Everything but the focused window is dimmed. Focus "
                    + "another window and it becomes the clear one."
            )
        case (false, true):
            return L(
                "kiwivision.preview.caption.blur",
                "Everything but the focused window is blurred. Focus "
                    + "another window and it becomes the clear one."
            )
        case (false, false):
            return L(
                "kiwivision.preview.caption.none",
                "At these settings KiwiVision changes nothing on screen."
            )
        }
    }

    /// One VoiceOver element, the number last (localization.md).
    func spoken(dimPercent: Double) -> String {
        let dim = SettingsValueReadout.percent(dimPercent / 100)
        switch (dims, blurs) {
        case (true, true):
            return L(
                "kiwivision.preview.ax.dim_blur",
                "KiwiVision preview: every window but the focused "
                    + "one is dimmed and blurred; focus another window "
                    + "and it becomes the clear one. Dim: %1$@",
                dim
            )
        case (true, false):
            return L(
                "kiwivision.preview.ax.dim",
                "KiwiVision preview: every window but the focused "
                    + "one is dimmed; focus another window and it "
                    + "becomes the clear one. Dim: %1$@",
                dim
            )
        case (false, true):
            return L(
                "kiwivision.preview.ax.blur",
                "KiwiVision preview: every window but the focused "
                    + "one is blurred; focus another window and it "
                    + "becomes the clear one."
            )
        case (false, false):
            return L(
                "kiwivision.preview.ax.none",
                "KiwiVision preview: nothing changes at these settings."
            )
        }
    }
}
