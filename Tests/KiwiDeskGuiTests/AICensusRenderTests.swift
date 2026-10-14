import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The AI page against the census (#1685). The prompts card is a
/// `ForEach` over its order list, so a ready-made prompt ships by
/// editing the census; the setup card draws its one row by hand.
@Suite("AI render ↔ census parity")
struct AICensusRenderTests {
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
    @MainActor func everyPromptHasText() {
        LocalizationManager.shared.select("en")
        for row in AIRowOrder.readyMadePrompts {
            guard case .ai(let key) = row else {
                Issue.record("\(row.id) is not an AI row")
                continue
            }
            let caption = AIReadyPrompt.caption(for: key) ?? ""
            #expect(!caption.isEmpty, "\(key)")
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
        #expect(!squashed.contains("AIRowOrder.setup"))
    }
}
