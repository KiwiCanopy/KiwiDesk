import SwiftUI

/// A Shortcuts row that holds a setting rather than a key (#2670):
/// the shortcut rows' columns, its value control in the recorder's
/// footprint and its "Applies to" control in their reach column, so
/// every such row lines up with the key rows around it. The one
/// door for such a row (`ShortcutSettingRowSeamTests`).
struct ShortcutSettingRow<Reach: View, Control: View>: View {
    /// Drawn twin of the control's own spoken name.
    let title: String
    let help: String
    /// What the `?` names for VoiceOver; the title unless a group
    /// heading names the subject better.
    let helpSubject: String
    let reach: Reach
    let control: Control

    init(
        title: String,
        help: String,
        helpSubject: String? = nil,
        @ViewBuilder reach: () -> Reach,
        @ViewBuilder control: () -> Control
    ) {
        self.title = title
        self.help = help
        self.helpSubject = helpSubject ?? title
        self.reach = reach()
        self.control = control()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            // The icon slot every shortcut row reserves (#264).
            Color.clear
                .frame(width: SettingsMetrics.shortcutIconSlot, height: 1)
            Text(title)
                .accessibilityHidden(true)
            HelpButton(explanation: help, subject: helpSubject)
            Spacer()
            reach
            KeyRecorderField.footprint.overlay { control }
        }
    }
}

extension ShortcutSettingRow where Reach == EmptyView {
    init(
        title: String,
        help: String,
        @ViewBuilder control: () -> Control
    ) {
        self.init(
            title: title,
            help: help,
            reach: { EmptyView() },
            control: control
        )
    }
}
