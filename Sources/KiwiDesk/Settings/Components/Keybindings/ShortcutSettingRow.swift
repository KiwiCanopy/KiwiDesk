import SwiftUI

/// A Shortcuts row that holds a setting rather than a key (#2670):
/// the shortcut rows' columns, its value control in the recorder's
/// footprint and its "Applies to" control in their reach column, so
/// every such row lines up with the key rows around it. The one
/// door for such a row (`ShortcutSettingRowSeamTests`).
struct ShortcutSettingRow<Reach: View, Control: View>: View {
    /// Drawn twin of the control's own spoken name.
    let title: String
    /// Its `?`, nil for a row whose title says it all (#3089).
    let help: String?
    /// What the `?` names for VoiceOver; the title unless a group
    /// heading names the subject better.
    let helpSubject: String
    let reach: Reach
    let control: Control
    /// An on/off's leading checkbox, which carries the title in
    /// place of the drawn label (#2439, #3089); nil for a row whose
    /// value control sits in the footprint.
    var checkbox: Binding<Bool>?
    /// Why the checkbox is greyed, nil while it is live.
    var checkboxGrey: String?
    @Environment(\.keybindingReservesTrashSlot)
    private var reservesTrashSlot

    init(
        title: String,
        help: String?,
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

    /// The glyph every setting row draws in its icon slot.
    static var settingGlyph: String { "slider.horizontal.3" }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            // A setting row wears the one setting glyph, never a
            // topic's (owner, 2026-10-27).
            IconGlyphLabel(icon: Self.settingGlyph)
                .frame(width: SettingsMetrics.shortcutIconSlot)
                .accessibilityHidden(true)
            if let checkbox {
                Toggle(title, isOn: checkbox)
                    .toggleStyle(.checkbox)
                    .modifier(
                        GreyOut(
                            active: checkboxGrey != nil,
                            help: checkboxGrey ?? ""
                        )
                    )
            } else {
                Text(title)
                    .accessibilityHidden(true)
            }
            if let help {
                HelpButton(explanation: help, subject: helpSubject)
            }
            Spacer()
            reach
            KeyRecorderField.footprint.overlay { control }
            if reservesTrashSlot {
                AppRuleDeleteButton.slot
            }
        }
    }
}

extension ShortcutSettingRow where Reach == EmptyView {
    init(
        title: String,
        help: String?,
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

extension ShortcutSettingRow where Control == EmptyView {
    /// An on/off setting: a leading checkbox carrying the title,
    /// greyed with `grey` as its reason, and an empty footprint so
    /// the reach column still lines up (#2439, #3089).
    init(
        title: String,
        help: String?,
        isOn: Binding<Bool>,
        grey: String? = nil,
        @ViewBuilder reach: () -> Reach
    ) {
        self.init(
            title: title,
            help: help,
            reach: reach,
            control: { EmptyView() }
        )
        checkbox = isOn
        checkboxGrey = grey
    }
}
