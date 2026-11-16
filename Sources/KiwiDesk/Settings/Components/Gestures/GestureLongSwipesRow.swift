import KiwiDeskCore
import SwiftUI

/// The Trackpad card's foot (#3369 ▸ Ruling): Long swipes, one
/// setting per profile, never per binding, with its "Applies to".
/// It greys, never hides, while no two-finger swipe runs the pan,
/// and its reason is drawn outside the grey (gui.md ▸ a dim is not
/// a sentence).
struct GestureLongSwipesRow: View {
    @ObservedObject var model: SettingsModel

    private var reason: ShortcutsGates.InertReason? {
        ShortcutsGates(config: model.config)
            .inertReason(for: .shortcuts(.scrollLongSwipes))
    }

    var body: some View {
        let greyed = reason != nil
        VStack(alignment: .leading, spacing: 4) {
            ShortcutSettingRow(
                title: ScrollGestureWords.longSwipes,
                help: nil,
                isOn: $model.config.scrollGesture.longSwipes,
                grey: greyed ? Self.caption : nil,
                reach: { reach }
            )
            .searchAnchored(
                SettingsCatalog.shortcuts.gestures.children.longSwipes
            )
            if greyed {
                Text(Self.caption)
                    .font(.caption)
                    .foregroundStyle(SettingsTheme.ink3)
                    .padding(.leading, SettingsMetrics.shortcutTextIndent)
            }
        }
    }

    /// Why the checkbox greys, in the card's own family names.
    static var caption: String {
        L(
            "shortcuts.gestures.scroll.long_swipes_off",
            "Works once a two-finger swipe is set to %1$@ or %2$@.",
            GestureListWords.family(.focus),
            GestureListWords.family(.walk)
        )
    }

    @ViewBuilder private var reach: some View {
        let field = ScrollGestureField.longSwipes
        if model.offersReachColumn,
            let reading = model.scrollReach(field.rawValue)
        {
            RuleReachControl(
                model: model,
                family: .scroll,
                app: field.rawValue,
                subject: ScrollGestureWords.label(field),
                reading: reading,
                value: ScrollGestureWords.value(
                    field.value(in: model.config.scrollGesture)
                )
            )
        }
    }
}
