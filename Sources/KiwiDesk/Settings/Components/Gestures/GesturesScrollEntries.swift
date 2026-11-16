import KiwiDeskCore
import SwiftUI

/// Mouse & Trackpad ▸ Holding a modifier (#1656, #1519, #3184): the
/// ⌃⌥ entry with its Long swipes box, then the ⌃⌥⌘ entry; their
/// chords and Natural scrolling live in the Mouse and Trackpad
/// cards (#3183). Each
/// value carries the shortcut rows' "Applies to" checklist, every
/// one ending on the pane's right edge, and every control starts
/// on the sentence's column; the draft holds the header profile's
/// resolved values.
struct GesturesScrollEntries: View {
    @ObservedObject var model: SettingsModel

    private var gestures: ScrollGestureBase { model.config.scrollGesture }

    var body: some View {
        GestureEntry(
            .scrollStep,
            settings: model.config.settings,
            gestures: gestures
        ) {
            // The step length is Lua-only (#1873 ▸ Ruling 2026-11-16).
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
        }
        .gestureAnchored(.scrollStep)
        GestureRule()
        spaceStepEntry
    }

    private static var controls: GesturesControls {
        SettingsCatalog.shortcuts.gestures.children
    }

    /// ⌃⌥⌘ + swipe (#1519), and a mouse's ⌃⌥ sideways wheel
    /// (#3281): one Space per swipe or notch, so no swipe-length
    /// rows.
    private var spaceStepEntry: some View {
        GestureEntry(
            .spaceStep,
            settings: model.config.settings,
            gestures: gestures
        ) {
            EmptyView()
        }
        .gestureAnchored(.spaceStep)
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
