import KiwiDeskCore
import SwiftUI

/// Long swipes' dependent row at the Trackpad card's foot (#3505,
/// owner and ui-designer 2026-11-19): the finger travel per window,
/// a log-scaled slider between Short and Long with no readout and a
/// tick at the default. Global only, so it carries no reach column.
/// It greys, never hides, while Long swipes is off or greyed; the
/// checkbox above is its cause, so it draws no caption of its own.
struct GestureStepLengthRow: View {
    @ObservedObject var model: SettingsModel

    private var reason: ShortcutsGates.InertReason? {
        ShortcutsGates(config: model.config)
            .inertReason(for: .shortcuts(.scrollStepLength))
    }

    /// Where a dependent of the Long swipes checkbox starts: past the
    /// gesture columns and the checkbox, on its label's edge.
    static let indent: CGFloat =
        GestureListRow.textIndent + ToggleRow.captionIndent

    var body: some View {
        HStack(spacing: GestureListRow.rowGap) {
            Text(ScrollGestureWords.stepLength)
                .accessibilityHidden(true)
            HStack(spacing: 6) {
                end(ScrollGestureWords.stepShort)
                SettingsSlider(
                    value: position,
                    range: 0...1,
                    step: 0,
                    label: ScrollGestureWords.stepLength,
                    spokenValue: ScrollGestureWords.stepSpoken(
                        model.config.scrollGesture.stepLength
                    ),
                    tick: StepLengthScale.defaultPosition,
                    keyStep: StepLengthScale.notch
                )
                end(ScrollGestureWords.stepLong)
            }
            AppRuleDeleteButton.slot
        }
        .padding(.leading, Self.indent)
        .modifier(GreyOut(active: reason != nil, help: help))
        .searchAnchored(
            SettingsCatalog.shortcuts.gestures.children.stepLength
        )
    }

    /// The tooltip while greyed: Long swipes' own reason where it is
    /// greyed too; none where it is merely off, being right above.
    private var help: String {
        reason == .noPanSwipe ? GestureLongSwipesRow.caption : ""
    }

    private var position: Binding<Double> {
        Binding(
            get: {
                StepLengthScale.position(
                    of: model.config.scrollGesture.stepLength
                )
            },
            set: {
                let stored = model.config.scrollGesture.stepLength
                guard !StepLengthScale.keeps(stored, at: $0) else { return }
                model.config.scrollGesture.stepLength =
                    StepLengthScale.length(at: $0)
            }
        )
    }

    private func end(_ word: String) -> some View {
        Text(word)
            .font(.caption)
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)
    }
}
