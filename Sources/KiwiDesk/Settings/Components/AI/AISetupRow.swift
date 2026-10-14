import KiwiDeskCore
import SwiftUI

/// AI ▸ Set up's one row: Copy Setup Prompt, its `?`, and the
/// caption. A copy opened from Downloads runs from a translocated
/// path that dies at relaunch, so there the button greys and the
/// caption says why — the login item's one predicate, read at
/// render (#1685 ▸ Ruling 6a). A bare binary keeps the button.
struct AISetupRow: View {
    @EnvironmentObject private var localization: LocalizationManager

    var body: some View {
        let translocated =
            LoginItemManager.unavailableCopy == .translocated
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                AICopyButton(title: title, text: prompt)
                    .modifier(GreyOut(active: translocated))
                HelpButton(explanation: help, subject: title)
            }
            Text(translocated ? movedCaption : caption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .searchAnchored(SettingsCatalog.ai.copySetupPrompt)
    }

    private func prompt() -> String {
        AISetupPrompt.text(
            executable: Bundle.main.executablePath ?? "",
            replyLanguage: AISetupPrompt.replyLanguage(
                for: localization.effectiveLocale
            )
        )
    }

    private var title: String {
        L("ai.setup.copy", "Copy Setup Prompt")
    }

    private var caption: String {
        L(
            "ai.setup.copy.caption",
            "Paste it into Claude Desktop, Claude Code, Cursor or "
                + "Codex. It holds everything the app needs to "
                + "connect to KiwiDesk."
        )
    }

    private var movedCaption: String {
        L(
            "ai.setup.translocated",
            "Move KiwiDesk to your Applications folder first. "
                + "Opened from Downloads, it runs from a temporary "
                + "location that changes each time it starts."
        )
    }

    private var help: String {
        L(
            "ai.setup.copy.help",
            "MCP (Model Context Protocol) is how an AI app uses "
                + "tools on your Mac. KiwiDesk gives it the same "
                + "commands as the kiwidesk command line."
        )
    }
}
