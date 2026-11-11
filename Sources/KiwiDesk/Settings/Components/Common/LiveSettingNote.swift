import KiwiDeskCore
import SwiftUI

/// The one sentence a setting that skips Save carries (#3218):
/// app-wide, written at once, so the Save pill never names it. It
/// leads the smallest unit that is wholly live — a card under its
/// title, a row under its label — and colour never carries it.
@MainActor
enum LiveSettingNote {
    static var text: String {
        L(
            "settings.applies_at_once",
            "Changes apply at once, in every profile."
        )
    }
}

/// `LiveSettingNote` as a row's caption, in secondary ink.
struct LiveSettingCaption: View {
    var body: some View {
        Text(LiveSettingNote.text)
            .font(.caption)
            .foregroundStyle(SettingsTheme.ink2)
            .fixedSize(horizontal: false, vertical: true)
    }
}
