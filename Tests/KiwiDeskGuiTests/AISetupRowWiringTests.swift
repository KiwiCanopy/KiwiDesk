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
        #expect(
            row.occurrences(of: ".modifier(GreyOut(active:translocated))")
                == 1
        )
        #expect(
            row.occurrences(of: "Text(translocated?movedCaption:caption)")
                == 1
        )
        #expect(
            row.occurrences(
                of: "executable:RunningCopy.executablePath"
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
