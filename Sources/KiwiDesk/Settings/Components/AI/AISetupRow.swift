import AppKit
import KiwiDeskCore
import SwiftUI

/// AI ▸ Set up's two rows (#2258 ▸ Ruling 7), in the prompts'
/// row shape: Claude Desktop first, then Other AI apps with its
/// `?`. A copy opened from Downloads runs from a translocated path
/// that dies at relaunch, so there both buttons grey and the move
/// sentence is drawn once, as the second row's caption — the
/// census gate `runningCopyTranslocated`, read from the one
/// `RunningCopy` verdict at render (#1685 ▸ Ruling 6a).
/// Without Claude Desktop only the first button greys, with its
/// reason; installing it while Settings is open lights it on return.
/// That cause stays out of the census on purpose: it is a fact about
/// another app, read live, with no setting that owns it.
struct AISetupRow: View {
    @EnvironmentObject private var localization: LocalizationManager
    /// Nil until first read, so no "install first" flashes.
    @State private var claudeInstalled: Bool?
    @State private var building = false
    @State private var addFailed = false
    @State private var announcement: DispatchWorkItem?

    var body: some View {
        let translocated = RunningCopy.location == .translocated
        VStack(alignment: .leading, spacing: 8) {
            SettingsActionRow(
                title: SettingsCatalog.ai.addToClaudeDesktop.text,
                caption: translocated ? nil : addCaption
            ) {
                addButton(translocated: translocated)
            }
            .searchAnchored(SettingsCatalog.ai.addToClaudeDesktop)
            Divider()
            SettingsActionRow(
                title: SettingsCatalog.ai.copySetupPrompt.text,
                caption: translocated ? movedCaption : caption,
                help: help
            ) {
                AICopyButton(title: copyTitle, text: prompt)
                    .modifier(GreyOut(active: translocated))
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

    private func addButton(translocated: Bool) -> some View {
        Button(action: add) {
            Label(
                L("ai.setup.add", "Add…"),
                systemImage: "puzzlepiece.extension"
            )
        }
        .settingsActionButton()
        .accessibilityLabel(
            L("ai.setup.add.ax", "Add to Claude Desktop")
        )
        .modifier(
            GreyOut(
                active: translocated || claudeInstalled == false
                    || building
            )
        )
    }

    private func refreshClaude() {
        claudeInstalled = MCPDesktopExtension.claudeDesktop() != nil
    }

    private func add() {
        addFailed = false
        building = true
        Task { @MainActor in
            defer { building = false }
            do {
                try await MCPDesktopExtension.addToClaudeDesktop()
            } catch MCPDesktopExtension.Failure.noClaudeDesktop {
                refreshClaude()
            } catch {
                failAdd()
            }
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

    private var addCaption: String {
        if addFailed { return addFailedCaption }
        guard claudeInstalled != false else {
            return L(
                "ai.setup.claude_desktop.missing",
                "Install Claude Desktop first."
            )
        }
        return L(
            "ai.setup.desktop.caption",
            "Opens Claude Desktop, which asks you to install "
                + "KiwiDesk’s extension."
        )
    }

    private var addFailedCaption: String {
        L(
            "ai.setup.claude_desktop.failed",
            "Couldn’t add the extension to Claude Desktop. Try "
                + "again, or use %1$@ below.",
            L("ai.setup.copy", "Copy Setup Prompt")
        )
    }

    private var copyTitle: String {
        L("ai.setup.copy", "Copy Setup Prompt")
    }

    private var caption: String {
        L(
            "ai.setup.coding_apps.caption",
            "Claude Code, Cursor or Codex: paste the setup prompt "
                + "into it. It holds everything the app needs to "
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
            "ai.setup.coding_apps.help",
            "MCP is the standard way an AI app uses tools on "
                + "your Mac. KiwiDesk gives it the same commands "
                + "you can type in Terminal."
        )
    }
}
