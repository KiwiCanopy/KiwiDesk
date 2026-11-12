import KiwiDeskCore
import SwiftUI

/// Mouse & Trackpad ▸ Holding a modifier (#1656, #1519, #3184): its
/// first group. The ⌃⌥ entry with its swipe length, then the ⌃⌥⌘
/// entry; their chords and Natural scrolling live in the Mouse and
/// Trackpad cards below (#3183). Each
/// value carries the shortcut rows' "Applies to" checklist, every
/// one ending on the pane's right edge, and every control starts
/// on the sentence's column; the draft holds the header profile's
/// resolved values.
struct GesturesScrollEntries: View {
    @ObservedObject var model: SettingsModel
    /// The entry that plays once as it appears, spending this
    /// (`GesturesPart`).
    @Binding var playing: GestureItem?

    private var gestures: ScrollGestureBase { model.config.scrollGesture }

    var body: some View {
        GestureEntry(
            .scrollStep,
            settings: model.config.settings,
            gestures: gestures,
            playing: $playing
        ) {
            VStack(alignment: .leading, spacing: 8) {
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
                    travelRow
                }
            }
        }
        .gestureAnchored(.scrollStep)
        GestureRule()
        spaceStepEntry
    }

    private static var controls: GesturesControls {
        SettingsCatalog.shortcuts.gestures.children
    }

    /// ⌃⌥⌘ + scroll (#1519): one Space per swipe or notch, so no
    /// swipe-length rows.
    private var spaceStepEntry: some View {
        GestureEntry(
            .spaceStep,
            settings: model.config.settings,
            gestures: gestures,
            playing: $playing
        ) {
            EmptyView()
        }
        .gestureAnchored(.spaceStep)
    }

    /// Indented under the box it depends on, and greyed — never
    /// hidden — while that box is off.
    private var travelRow: some View {
        StepperRow(
            label: ScrollGestureWords.stepDistance,
            value: stepDistance,
            in: Self.stepDistanceRange,
            step: 10,
            suffix: L("shortcuts.gestures.scroll.points", "pt")
        )
        .fixedSize()
        .disabled(!gestures.longSwipes)
        .padding(.leading, 20)
        .searchAnchored(
            SettingsCatalog.shortcuts.gestures.children.stepDistance
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
