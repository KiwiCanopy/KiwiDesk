import KiwiDeskCore
import SwiftUI

/// Mouse & trackpad ▸ Scroll gestures (#1656): the drawer's first
/// group. The ⌃⌥ entry with its recorder and swipe length, then
/// the two Natural scrolling rows every scroll gesture shares. Each
/// value carries the shortcut rows' "Applies to" checklist; the
/// draft holds the header profile's resolved values.
struct GesturesScrollEntries: View {
    @ObservedObject var model: SettingsModel

    private var gestures: ScrollGestureBase { model.config.scrollGesture }

    var body: some View {
        GestureEntry(
            L(
                "shortcuts.gestures.scroll.sentence",
                "Hold these keys and scroll to move focus window by "
                    + "window along a Scrolling row. On a Monocle "
                    + "Space it steps through the windows instead."
            ),
            surface: .windows,
            settings: model.config.settings,
            pace: .steps
        ) {
            GesturePicture.ScrollStep(t: $0, chord: gestures.pan)
        } control: {
            VStack(alignment: .leading, spacing: 8) {
                reachRow(.pan) {
                    ScrollChordRecorderField(
                        name: ScrollGestureWords.pan,
                        chord: $model.config.scrollGesture.pan,
                        other: gestures.spaceStep
                    )
                    .searchAnchored(
                        SettingsCatalog.shortcuts.gestures.children
                            .scrollPan
                    )
                }
                reachRow(.longSwipes) {
                    Toggle(
                        ScrollGestureWords.longSwipes,
                        isOn: $model.config.scrollGesture.longSwipes
                    )
                    .toggleStyle(.checkbox)
                    .searchAnchored(
                        SettingsCatalog.shortcuts.gestures.children
                            .longSwipes
                    )
                }
                reachRow(.stepDistance) {
                    StepperRow(
                        label: ScrollGestureWords.stepDistance,
                        value: stepDistance,
                        in: Self.stepDistanceRange,
                        step: 10,
                        suffix: L("border.fit_gaps.unit", "pt")
                    )
                    // Grey, don't hide: it acts once the box is ticked.
                    .disabled(!gestures.longSwipes)
                    .searchAnchored(
                        SettingsCatalog.shortcuts.gestures.children
                            .stepDistance
                    )
                }
            }
        }
        GestureRule()
        naturalRow(
            .naturalTrackpad,
            ScrollGestureWords.trackpad,
            $model.config.scrollGesture.naturalTrackpad
        )
        .searchAnchored(
            SettingsCatalog.shortcuts.gestures.children.naturalTrackpad
        )
        naturalRow(
            .naturalMouse,
            ScrollGestureWords.mouse,
            $model.config.scrollGesture.naturalMouse
        )
        .searchAnchored(
            SettingsCatalog.shortcuts.gestures.children.naturalMouse
        )
    }

    /// Core's bounds, as the stepper's whole points.
    static var stepDistanceRange: ClosedRange<Int> {
        let range = ScrollGestureBase.stepDistanceRange
        return Int(range.lowerBound)...Int(range.upperBound)
    }

    private var stepDistance: Binding<Int> {
        Binding(
            get: { Int(model.config.scrollGesture.stepDistance.rounded()) },
            set: { model.config.scrollGesture.stepDistance = Double($0) }
        )
    }

    /// Apple's own toggle under a row naming the input it reads.
    private func naturalRow(
        _ field: ScrollGestureField,
        _ input: String,
        _ isOn: Binding<Bool>
    ) -> some View {
        reachRow(field) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(input)
                    .accessibilityHidden(true)
                Toggle(isOn: isOn) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(ScrollGestureWords.natural)
                        Text(ScrollGestureWords.naturalCaption)
                            .font(.caption)
                            .foregroundStyle(SettingsTheme.ink3)
                    }
                }
                .toggleStyle(.checkbox)
                .accessibilityLabel(
                    L(
                        "shortcuts.gestures.scroll.natural_spoken",
                        "%1$@, %2$@",
                        input,
                        ScrollGestureWords.natural
                    )
                )
            }
        }
        .padding(.vertical, 2)
    }

    /// A value's control with its "Applies to" column trailing.
    private func reachRow<Content: View>(
        _ field: ScrollGestureField,
        @ViewBuilder _ content: () -> Content
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            content()
            Spacer(minLength: 8)
            reach(field)
        }
    }

    @ViewBuilder private func reach(_ field: ScrollGestureField) -> some View {
        if model.offersReachColumn,
            let reading = model.scrollReach(field.rawValue)
        {
            RuleReachControl(
                model: model,
                family: .scroll,
                app: field.rawValue,
                subject: ScrollGestureWords.label(field),
                reading: reading,
                value: ScrollGestureWords.value(field.value(in: gestures))
            )
        }
    }
}
