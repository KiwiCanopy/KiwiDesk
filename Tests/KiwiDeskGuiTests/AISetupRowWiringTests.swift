import Foundation
import Testing

/// The AI page's setup row against its census gate (#1685): the
/// grey and the inline reason both read the one `RunningCopy`
/// verdict, and the setup prompt stays English — a ruled
/// exception to `L()` (localization.md ▸ Call sites).
@Suite("AI setup row wiring")
struct AISetupRowWiringTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    private func flat(_ path: String) throws -> String {
        try SourceScan.strippedSource(
            at: Self.root.appendingPathComponent(path)
        )
        .split(whereSeparator: \.isWhitespace).joined()
    }

    @Test("the grey and its reason read the running copy")
    func greyAndReasonAreWired() throws {
        let row = try flat(
            "Sources/KiwiDesk/Settings/Components/AI/AISetupRow.swift"
        )
        #expect(
            row.occurrences(
                of: "lettranslocated=RunningCopy.location"
                    + "==.translocated"
            ) == 1
        )
        // Tied to the button, so a grey on the `?` reds.
        #expect(
            row.occurrences(
                of: "AICopyButton(title:copyTitle,text:prompt)"
                    + ".modifier(GreyOut(active:translocated))"
            ) == 1
        )
        #expect(
            row.occurrences(
                of: "caption:translocated?movedCaption:caption"
            ) == 1
        )
        #expect(
            row.occurrences(
                of: "executable:RunningCopy.executablePath"
            ) == 1
        )
        // The census hit lands on the row (#1250).
        #expect(
            row.occurrences(
                of: ".searchAnchored(SettingsCatalog.ai.copySetupPrompt)"
            ) == 1
        )
    }

    /// Add to Claude Desktop (#2258 ▸ Ruling 7): it greys with the
    /// shared translocation reason drawn once, re-reads whether
    /// Claude Desktop is installed whenever KiwiDesk comes back,
    /// and hands the click to the one generator.
    @Test("Add to Claude Desktop greys, refreshes and builds")
    func addRowIsWired() throws {
        let row = try flat(
            "Sources/KiwiDesk/Settings/Components/AI/AISetupRow.swift"
        )
        // Its own caption is withheld while translocated, so the
        // move sentence under Copy is the one reason drawn.
        #expect(
            row.occurrences(of: "caption:translocated?nil:addCaption") == 1
        )
        #expect(
            row.occurrences(
                of: "NSApplication.didBecomeActiveNotification"
            ) == 1
        )
        // Read on appear and on return, never in the initializer.
        #expect(
            row.occurrences(
                of: "MCPDesktopExtension.claudeDesktop()!=nil"
            ) == 1
        )
        #expect(row.occurrences(of: ".onAppear(perform:refreshClaude)") == 1)
        #expect(
            row.occurrences(
                of: "tryawaitMCPDesktopExtension.addToClaudeDesktop()"
            ) == 1
        )
        // A build in flight greys the button; a Claude Desktop
        // removed since the last read re-reads instead of failing.
        #expect(row.occurrences(of: "||building") == 1)
        // "Add…" alone names nothing: VoiceOver hears the target,
        // on the Add button's own chain.
        #expect(
            row.occurrences(
                of: ".settingsActionButton()"
                    + ".accessibilityLabel(L(\"ai.setup.add.ax\","
            ) == 1
        )
        // …and the grey always lifts, whatever the build answered.
        #expect(row.occurrences(of: "defer{building=false}") == 1)
        #expect(
            row.occurrences(
                of: "catchMCPDesktopExtension.Failure.noClaudeDesktop"
                    + "{refreshClaude()}"
            ) == 1
        )
        #expect(
            row.occurrences(
                of: ".searchAnchored(SettingsCatalog.ai.addToClaudeDesktop)"
            ) == 1
        )
    }

    /// The row draws the caption the census guard checks.
    @Test("a prompt row draws its prompt's caption")
    func promptRowDrawsTheCaption() throws {
        let row = try flat(
            "Sources/KiwiDesk/Settings/Components/AI/AIPromptRow.swift"
        )
        #expect(
            row.occurrences(
                of: "caption:AIReadyPrompt.caption(for:key)??\"\""
            ) == 1
        )
    }

    @Test("the setup prompt spells no localized string")
    func setupPromptStaysEnglish() throws {
        let prompt = try flat(
            "Sources/KiwiDesk/Settings/Components/AI/AISetupPrompt.swift"
        )
        #expect(prompt.contains("PleaseconnectKiwiDesk"))
        #expect(!prompt.contains("L("))
    }
}
