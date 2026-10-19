import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The AI page against the census (#1685). The prompts card is a
/// `ForEach` over its order list, so a ready-made prompt ships by
/// editing the census; the setup card draws its one row by hand.
@Suite("AI render ↔ census parity")
struct AICensusRenderTests {
    /// `AIReadyPrompt`'s source, where each caption's `L()` key
    /// is spelled — the drawn caption, not a census copy of it.
    private static let readyPromptSource: String = {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/AI/"
                    + "AIReadyPrompt.swift"
            )
        return (try? SourceScan.strippedSource(at: url)) ?? ""
    }()

    private func censusRows(
        _ container: SettingsContainer
    ) -> Set<SettingKey> {
        Set(
            SettingKey.allCases.filter {
                $0.placement.area == .ai
                    && $0.placement.container == container
            }
        )
    }

    @Test("each container lists exactly its census rows")
    func listsMatchCensus() {
        for (container, order) in AIRowOrder.byContainer {
            #expect(Set(order) == censusRows(container))
            #expect(order.count == Set(order).count)
        }
        let declared = Set(
            SettingKey.allCases
                .filter { $0.placement.area == .ai }
                .compactMap { $0.placement.container }
        )
        #expect(declared == Set(AIRowOrder.byContainer.keys))
    }

    /// Each row's catalog control carries that row's label key,
    /// which lets a census search hit resolve to the row (#1250).
    @Test("every row anchors on its own label key")
    @MainActor func rowsAnchorOnTheirLabelKey() {
        for key in AIKey.allCases {
            let control = AISection.control(for: key)
            #expect(control?.key == key.labelKey, "\(key)")
            guard case .key(let label) = key.text.label else {
                Issue.record("\(key) has no static label")
                continue
            }
            #expect(label == key.labelKey)
        }
    }

    /// A ready-made prompt row with no text would copy an empty
    /// clipboard, one with no caption draws a bare title — every
    /// listed prompt has both.
    @Test("every ready-made prompt has its caption and text")
    @MainActor func everyPromptHasText() throws {
        LocalizationManager.shared.select("en")
        #expect(!AIRowOrder.readyMadePrompts.isEmpty)
        for row in AIRowOrder.readyMadePrompts {
            guard case .ai(let key) = row else {
                Issue.record("\(row.id) is not an AI row")
                continue
            }
            let caption = AIReadyPrompt.caption(for: key) ?? ""
            #expect(!caption.isEmpty, "\(key)")
            // The drawn caption's key is the census row's.
            let captionKey = try #require(key.text.captionKey)
            #expect(
                Self.readyPromptSource.occurrences(
                    of: "\"\(captionKey)\""
                ) == 1,
                "\(key)"
            )
            let text = AIReadyPrompt.text(for: key) ?? ""
            #expect(text.contains("one question at a time"), "\(key)")
            #expect(text.contains("keep"), "\(key)")
        }
    }

    /// The Spaces prompt names every layout once, by the label
    /// the Layouts page draws (#818).
    @Test("the Spaces prompt names every layout")
    @MainActor func spacesPromptNamesEveryLayout() {
        LocalizationManager.shared.select("en")
        #expect(
            Set(AIReadyPrompt.spacesLayouts)
                == Set(LayoutMode.allCases)
        )
        #expect(
            AIReadyPrompt.spacesLayouts.count
                == LayoutMode.allCases.count
        )
        let text = AIReadyPrompt.text(for: .promptSpaces) ?? ""
        for mode in LayoutMode.allCases {
            #expect(text.contains(mode.displayName), "\(mode)")
        }
    }

    /// The look row leads the prompts (#1685 ▸ Ruling 6a), and its
    /// ruled text asks for a screenshot of the wallpaper.
    @Test("the look prompt leads and asks for a screenshot")
    @MainActor func lookPromptLeads() {
        LocalizationManager.shared.select("en")
        #expect(AIRowOrder.readyMadePrompts.first == .ai(.promptLook))
        let text = AIReadyPrompt.text(for: .promptLook) ?? ""
        #expect(text.contains("screenshot"))
    }

    /// The prompts keep their ruled order (#1685 ▸ Ruling 6a), and
    /// the migration prompt has the shortcuts shown before they
    /// are added, since they save at once (Ruling 6c).
    @Test("the prompts keep their ruled order")
    @MainActor func promptsKeepRuledOrder() {
        LocalizationManager.shared.select("en")
        #expect(
            AIRowOrder.readyMadePrompts == [
                .ai(.promptLook), .ai(.promptMigrate),
                .ai(.promptAppRules), .ai(.promptSpaces),
            ]
        )
        let text = AIReadyPrompt.text(for: .promptMigrate) ?? ""
        #expect(text.contains("shortcuts before you add them"))
    }

    /// The prompts card walks its list; the setup card draws its
    /// one row by hand, so the row must be mounted there.
    @Test("the prompts card walks its list, the setup row mounts")
    func promptsWalkTheirList() throws {
        let root = SourceScan.repoRoot(from: #filePath)
        let section = root.appendingPathComponent(
            "Sources/KiwiDesk/Settings/Sections/AISection.swift"
        )
        let source = try SourceScan.blankedSource(at: section)
        let squashed = source.split(
            whereSeparator: \.isWhitespace
        ).joined()
        #expect(
            squashed.contains(
                "ForEach(Array(AIRowOrder.readyMadePrompts"
                    + ".enumerated())"
            )
        )
        #expect(AIRowOrder.bespokeContainers == [.aiSetup])
        #expect(squashed.contains("AISetupRow()"))
        #expect(squashed.occurrences(of: "AIPromptRow(") == 1)
        #expect(!squashed.contains("AIRowOrder.setup"))
    }

    /// Both cards draw one row shape (owner ruling 2026-10-17):
    /// the setup row mounts `SettingsActionRow` twice — Claude
    /// Desktop before Other AI apps (#2258 ▸ Ruling 7) — and a prompt row
    /// once, so the two cards cannot drift apart.
    @Test("both cards draw the shared action row")
    func cardsShareTheActionRow() throws {
        let setup = try squashedAI("AISetupRow.swift")
        #expect(setup.occurrences(of: "SettingsActionRow(") == 2)
        let add = try #require(
            setup.range(of: "title:SettingsCatalog.ai.addToClaudeDesktop")
        )
        let copy = try #require(
            setup.range(of: "title:SettingsCatalog.ai.copySetupPrompt")
        )
        #expect(add.lowerBound < copy.lowerBound)
        let prompt = try squashedAI("AIPromptRow.swift")
        #expect(prompt.occurrences(of: "SettingsActionRow(") == 1)
        // The shared row lays out through the one row axis.
        let row = try SourceScan.strippedSource(
            at: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(
                    "Sources/KiwiDesk/Settings/Components/Common/"
                        + "SettingsActionRow.swift"
                )
        ).split(whereSeparator: \.isWhitespace).joined()
        #expect(row.occurrences(of: "SettingsRowShape(labelFills:true)") == 1)
        // The button names itself, so the title is drawn, not spoken.
        #expect(
            row.occurrences(of: "Text(title).accessibilityHidden(true)")
                == 1
        )
    }

    /// The setup rows draw the caption and help the census names
    /// for search, each spelled once (#1250).
    @Test("the setup rows draw their census caption and help")
    func setupRowsDrawTheirCensusText() throws {
        let setup = try squashedAI("AISetupRow.swift")
        for key in [AIKey.addToClaudeDesktop, .copySetupPrompt] {
            let caption = try #require(key.text.captionKey)
            #expect(
                setup.occurrences(of: "\"\(caption)\"") == 1,
                "\(key)"
            )
        }
        let help = try #require(AIKey.copySetupPrompt.text.helpKey)
        #expect(setup.occurrences(of: "\"\(help)\"") == 1)
        #expect(setup.occurrences(of: "help:help") == 1)
    }

    private func squashedAI(_ file: String) throws -> String {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/AI/" + file
            )
        return try SourceScan.strippedSource(at: url)
            .split(whereSeparator: \.isWhitespace).joined()
    }

    /// The setup card's intro is its header caption, the slot
    /// every card's framing sentence takes, never a body line
    /// drawn like the rows beneath it.
    @Test("the setup intro is the card's caption")
    func setupIntroIsTheCaption() throws {
        let root = SourceScan.repoRoot(from: #filePath)
        let section = root.appendingPathComponent(
            "Sources/KiwiDesk/Settings/Sections/AISection.swift"
        )
        let squashed = try SourceScan.strippedSource(at: section)
            .split(whereSeparator: \.isWhitespace).joined()
        #expect(squashed.contains("caption:L(\"ai.setup.intro\""))
        #expect(!squashed.contains("Text(L(\"ai.setup.intro\""))
    }

    /// The cards' ruled order (#1685 ▸ Ruling 6a, 2026-10-15): Set
    /// up, the ready-made prompts, then what the AI app can do.
    @Test("the cards keep their ruled order")
    func cardOrder() throws {
        let root = SourceScan.repoRoot(from: #filePath)
        let section = root.appendingPathComponent(
            "Sources/KiwiDesk/Settings/Sections/AISection.swift"
        )
        let source = try SourceScan.blankedSource(at: section)
        let squashed = source.split(
            whereSeparator: \.isWhitespace
        ).joined()
        #expect(squashed.contains("setupprompts" + "AICapabilitiesCard()"))
    }
}
