import KiwiDeskCore
import SwiftUI

/// Simple's Animations card (#3238): the speed preset, drawn by the
/// Animations card's own `AnimationSpeedRow`, under macOS Reduce
/// Motion's box with its one fix, as Advanced draws it.
struct SimpleAnimationsCard: View {
    @ObservedObject var model: SettingsModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        SimpleCard(title: SettingsCatalog.colors.motionCard.text) {
            VStack(alignment: .leading, spacing: 8) {
                if reduceMotion {
                    WarningBox(text: MotionCard.reduceMotionWarning) {
                        Button(MotionCard.openAccessibilityTitle) {
                            MotionCard.openAccessibilityDisplay()
                        }
                        .settingsActionButton()
                    }
                }
                AnimationSpeedRow(model: model)
            }
        }
    }
}
