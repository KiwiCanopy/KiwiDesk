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

/// The notice's content, laid out as the update window's checking
/// state: the app icon beside the lead and its help, the body, and
/// one OK in the footer bar. Its text takes the hierarchical styles,
/// which follow what the glass shows; a fixed ink read badly in
/// light mode over a dark backdrop (owner, 2026-11-25).
struct StandardFallbackView: View {
    let screenCount: Int
    let onOK: () -> Void
    /// Alert-sized, as `UpdateCheckingView`.
    static let width: CGFloat = 400

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 48, height: 48)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(StandardFallbackWords.lead(screenCount))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                        HelpButton(
                            explanation: StandardFallbackWords.help(
                                screenCount
                            )
                        )
                    }
                    Text(StandardFallbackWords.body(screenCount))
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(.top, 4)
            .padding(.horizontal, UpdateWindowMetrics.inset)
            .padding(.bottom, 22)
            StandardFallbackFooter(onOK: onOK)
        }
        .frame(width: Self.width)
        .updateWindowGround()
    }
}

/// One OK, which Return and Escape both answer — the notice
/// changes nothing, so there is nothing to decline. OK takes the
/// focus on appear so Escape reaches `onExitCommand`, as What's
/// new's footer does.
struct StandardFallbackFooter: View {
    let onOK: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        HStack {
            Spacer(minLength: 0)
            Button(L("standard_fallback.ok", "OK"), action: onOK)
                .settingsActionButton()
                .keyboardShortcut(.defaultAction)
                .focused($focused)
        }
        .updateFooterBar()
        .onAppear { focused = true }
        // Escape answers OK too; a Button cannot carry both.
        .onExitCommand(perform: onOK)
    }
}
