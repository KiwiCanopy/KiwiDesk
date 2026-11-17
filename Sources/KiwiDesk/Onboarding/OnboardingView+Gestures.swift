import KiwiDeskCore
import SwiftUI

extension OnboardingView {
    /// The gestures step (#1873 ▸ Ruling 2026-11-15, amended by
    /// #3427): KiwiHub's glyphs with a finger count or motion under
    /// them, a trackpad's rows and a mouse's behind Trackpad | Mouse
    /// where both have some, then ⌃⌥K for every one.
    var gestures: some View {
        let rows = model.gestureFamilies
        let mouse = model.gestureDevice == .mouse
        return OnboardingPage(
            title: L("onboarding.gestures.title", "Your gestures"),
            body1: mouse
                ? L(
                    "onboarding.gestures.mouse_body",
                    "These are ready on your mouse. Hold the keys, then "
                        + "scroll or drag."
                )
                : L(
                    "onboarding.gestures.body",
                    "These are ready on your trackpad. Hold the keys, "
                        + "then move your fingers."
                ),
            footnote: mouse
                ? OnboardingGestures.mouseFootnote(rows)
                : OnboardingGestures.footnote(
                    rows,
                    longSwipes: model.longSwipes()
                ),
            hint: L(
                "onboarding.gestures.hint",
                "Try one now — nothing will break."
            ),
            back: model.back
        ) {
            VStack(alignment: .leading, spacing: 4) {
                if model.offersGestureDevices {
                    gestureDevicePicker
                }
                ForEach(rows) { family in
                    if family.isGateway {
                        Divider().padding(.vertical, 4)
                    }
                    gestureRow(family)
                }
            }
        } action: {
            Button(L("onboarding.continue", "Continue")) {
                model.continueAfterGestures()
            }
            .kiwiProminentButton()
            .keyboardShortcut(.defaultAction)
        }
    }

    /// Trackpad | Mouse (#3427), centred over the rows as System
    /// Settings ▸ Trackpad and the Shortcuts page centre theirs.
    private var gestureDevicePicker: some View {
        SegmentedPicker(
            spokenLabel: L("onboarding.gestures.device", "Gestures for"),
            selection: Binding(
                get: { model.gestureDevice },
                set: { model.gestureDevice = $0 }
            ),
            options: [
                (
                    L("onboarding.gestures.device.trackpad", "Trackpad"),
                    GestureInput.Device.trackpad
                ),
                (
                    L("onboarding.gestures.device.mouse", "Mouse"),
                    GestureInput.Device.mouse
                ),
            ]
        )
        .fixedSize()
        .frame(maxWidth: .infinity)
        .padding(.bottom, 6)
    }

    private func gestureRow(_ family: OnboardingKeyFamily) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(family.label)
                .font(.system(size: 13.5))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 12)
            OnboardingKeycap(family: family)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(family.spoken ?? family.label)
    }
}
