import AppKit
import KiwiDeskCore
import SwiftUI

/// AI ▸ Set up's two rows (#2258 ▸ Ruling 7): Add to Claude Desktop
/// first, then Copy Setup Prompt with its `?`. A copy opened from
/// Downloads runs from a translocated path that dies at relaunch, so
/// there both buttons grey and the move sentence is drawn once, under
/// the second row — the census gate `runningCopyTranslocated`, read
/// from the one `RunningCopy` verdict at render (#1685 ▸ Ruling 6a).
/// Without Claude Desktop only the first button greys, with its
/// reason; installing it while Settings is open lights it on return.
struct AISetupRow: View {
    @EnvironmentObject private var localization: LocalizationManager
    @State private var claudeInstalled =
        MCPDesktopExtension.claudeDesktop() != nil
    @State private var addFailed = false
    @State private var announcement: DispatchWorkItem?

    var body: some View {
        let translocated = RunningCopy.location == .translocated
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Button(action: add) {
                    Label(addTitle, systemImage: "puzzlepiece.extension")
                }
                .settingsActionButton()
                .modifier(GreyOut(active: translocated || !claudeInstalled))
                if !translocated {
                    Text(addCaption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .searchAnchored(SettingsCatalog.ai.addToClaudeDesktop)
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
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSApplication.didBecomeActiveNotification
            )
        ) { _ in refreshClaude() }
        .onAppear(perform: refreshClaude)
        .onDisappear { announcement?.cancel() }
    }

    private func refreshClaude() {
        claudeInstalled = MCPDesktopExtension.claudeDesktop() != nil
    }

    private func add() {
        addFailed = false
        do {
            try MCPDesktopExtension.addToClaudeDesktop {
                failAdd()
            }
        } catch {
            failAdd()
        }
    }

    private func failAdd() {
        addFailed = true
        announcement?.cancel()
        announcement = DelayedAnnouncement.schedule(addFailedCaption)
    }

    private func prompt() -> String {
        AISetupPrompt.text(
            executable: RunningCopy.executablePath,
            replyLanguage: AISetupPrompt.replyLanguage(
                for: localization.effectiveLocale
            )
        )
    }

    private var addTitle: String {
        SettingsCatalog.ai.addToClaudeDesktop.text
    }

    private var addCaption: String {
        if addFailed { return addFailedCaption }
        guard claudeInstalled else {
            return L(
                "ai.setup.claude_desktop.missing",
                "Install Claude Desktop first."
            )
        }
        return L(
            "ai.setup.claude_desktop.caption",
            "Claude Desktop opens and asks you to install "
                + "KiwiDesk’s extension."
        )
    }

    private var addFailedCaption: String {
        L(
            "ai.setup.claude_desktop.failed",
            "Couldn’t create the extension. Try again, or use "
                + "%1$@ below.",
            title
        )
    }

    private var title: String {
        SettingsCatalog.ai.copySetupPrompt.text
    }

    private var caption: String {
        L(
            "ai.setup.copy.caption",
            "Paste it into Claude Code, Cursor or Codex. It holds "
                + "everything the app needs to connect to KiwiDesk."
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
            "MCP is the standard way an AI app uses tools on "
                + "your Mac. KiwiDesk gives it the same commands "
                + "you can type in Terminal."
        )
    }
}
