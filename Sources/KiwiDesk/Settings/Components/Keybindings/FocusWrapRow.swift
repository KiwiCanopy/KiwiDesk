import KiwiDeskCore
import SwiftUI

/// Focus ▸ Wrap focus (#2493): one segmented row directly above the
/// direction keys it governs, in the shortcut rows' shape, its
/// "Applies to" control in their reach column. Never greyed on one
/// screen: a profile outlives a docking, and This screen and All
/// screens then simply act alike.
struct FocusWrapRow: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            // The icon slot every shortcut row reserves (#264).
            Color.clear.frame(width: Self.iconSlot, height: 1)
            // The picker names itself; this is its drawn twin.
            Text(FocusWrapWords.title)
                .accessibilityHidden(true)
            picker
            HelpButton(
                explanation: FocusWrapWords.help,
                subject: FocusWrapWords.title
            )
            Spacer()
            reach
            KeyRecorderField.footprint
        }
    }

    private static let iconSlot = SettingsMetrics.shortcutIconSlot

    private var picker: some View {
        SegmentedPicker(
            spokenLabel: FocusWrapWords.title,
            spokenValue: FocusWrapWords.value(model.config.focusWrap),
            selection: $model.config.focusWrap,
            options: FocusWrap.allCases.map {
                (title: FocusWrapWords.value($0), value: $0)
            }
        )
        .fixedSize()
    }

    @ViewBuilder private var reach: some View {
        if model.offersReachColumn, let reading = model.wrapReach() {
            RuleReachControl(
                model: model,
                family: .wrap,
                app: RuleReachTable<FocusWrap>.focusWrapKey,
                subject: FocusWrapWords.title,
                reading: reading,
                value: FocusWrapWords.value(model.config.focusWrap)
            )
        }
    }
}

/// What the Wrap focus row is called and how its value reads — one
/// home for the row, the diff pill and the checklist.
@MainActor
enum FocusWrapWords {
    static var title: String {
        L("shortcuts.focus_wrap", "Wrap focus")
    }

    static var help: String {
        L(
            "shortcuts.focus_wrap.help",
            "%1$@: past the last window, focus returns to the first "
                + "on the same screen. %2$@: it continues to the next "
                + "screen, and past the last screen back to the first. "
                + "With one screen, both work the same. Either way, the "
                + "next and previous Space keys go round the screen's "
                + "Spaces, and %3$@ stops them at the last one.",
            value(.thisScreen),
            value(.allScreens),
            value(.off)
        )
    }

    static func value(_ mode: FocusWrap) -> String {
        switch mode {
        case .off: L("shortcuts.focus_wrap.off", "Off")
        case .thisScreen:
            L("shortcuts.focus_wrap.this_screen", "This screen")
        case .allScreens:
            L("shortcuts.focus_wrap.all_screens", "All screens")
        }
    }
}
