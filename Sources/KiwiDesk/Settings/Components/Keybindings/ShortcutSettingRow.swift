import SwiftUI

/// A Shortcuts row that holds a setting rather than a key (#2670):
/// the shortcut rows' columns, its value control in the recorder's
/// footprint and its "Applies to" control in their reach column, so
/// every such row lines up with the key rows around it.
struct ShortcutSettingRow<Reach: View, Control: View>: View {
    /// Drawn twin of the control's own spoken name.
    let title: String
    let help: String
    @ViewBuilder var reach: Reach
    @ViewBuilder var control: Control

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            // The icon slot every shortcut row reserves (#264).
            Color.clear.frame(width: Self.iconSlot, height: 1)
            Text(title)
                .accessibilityHidden(true)
            HelpButton(explanation: help, subject: title)
            Spacer()
            reach
            KeyRecorderField.footprint.overlay { control }
        }
    }

    static var iconSlot: CGFloat { SettingsMetrics.shortcutIconSlot }

    /// Where a caption under the row starts: under its title.
    static var captionIndent: CGFloat { iconSlot + 8 }
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
