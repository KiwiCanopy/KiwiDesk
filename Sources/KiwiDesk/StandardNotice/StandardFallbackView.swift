import KiwiDeskCore
import SwiftUI

/// The notice's words, one key per sentence and per plural form.
@MainActor
enum StandardFallbackWords {
    static func title(_ count: Int) -> String {
        count == 1
            ? L("standard_fallback.title.one", "Spaces for 1 Screen")
            : L(
                "standard_fallback.title.many",
                "Spaces for %1$d Screens",
                count
            )
    }

    static func lead(_ count: Int) -> String {
        count == 1
            ? L(
                "standard_fallback.lead.one",
                "KiwiDesk set up Spaces for 1 screen."
            )
            : L(
                "standard_fallback.lead.many",
                "KiwiDesk set up Spaces for %1$d screens.",
                count
            )
    }

    /// Names Settings' own save button through its key, so the
    /// words match the button in every catalog.
    static func body(_ count: Int) -> String {
        let save = L("footer.save_as_new_profile", "Save as New Profile…")
        return count == 1
            ? L(
                "standard_fallback.body.one",
                "Their layouts suit this screen's shape. To keep "
                    + "changes, choose %1$@ in Settings.",
                save
            )
            : L(
                "standard_fallback.body.many",
                "Their layouts suit these screens' shapes. To keep "
                    + "changes, choose %1$@ in Settings.",
                save
            )
    }

    static func help(_ count: Int) -> String {
        count == 1
            ? L(
                "standard_fallback.help.one",
                "Each profile is saved for one screen count. With no "
                    + "profile for 1 screen, KiwiDesk uses its Standard "
                    + "setup: a set of Spaces, each in the layout that "
                    + "suits your screen. Changes stay until you save "
                    + "them as a profile. From then on, that profile "
                    + "loads whenever 1 screen is connected."
            )
            : L(
                "standard_fallback.help.many",
                "Each profile is saved for one screen count. With no "
                    + "profile for %1$d screens, KiwiDesk uses its "
                    + "Standard setup: a set of Spaces, each in the "
                    + "layout that suits your screens. Changes stay "
                    + "until you save them as a profile. From then on, "
                    + "that profile loads whenever %1$d screens are "
                    + "connected.",
                count
            )
    }
}

/// The notice's content: the lead with its help, the body, OK.
/// OK changes nothing, so Return and Escape both give it.
struct StandardFallbackView: View {
    let screenCount: Int
    let onOK: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(StandardFallbackWords.lead(screenCount))
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                HelpButton(
                    explanation: StandardFallbackWords.help(screenCount)
                )
            }
            Text(StandardFallbackWords.body(screenCount))
                .font(.callout)
                .foregroundStyle(SettingsTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button(L("standard_fallback.ok", "OK"), action: onOK)
                    .keyboardShortcut(.defaultAction)
                    .settingsActionButton()
            }
        }
        .padding(EdgeInsets(top: 18, leading: 20, bottom: 16, trailing: 20))
        .frame(width: 360)
        .background(SettingsTheme.card)
        .onExitCommand(perform: onOK)
    }
}
