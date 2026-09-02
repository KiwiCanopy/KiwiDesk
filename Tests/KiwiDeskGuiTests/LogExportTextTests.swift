import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// Core names what stopped a log export, the GUI narrates it
/// (#96, #1209): every problem has a title and a sentence, the
/// write failure names the file, and the tool's stderr never
/// reaches the user.
@Suite("Log export narration")
@MainActor
struct LogExportTextTests {
    private let problems: [LogExportProblem] = [
        .empty, .toolFailed,
        .writeFailed(URL(fileURLWithPath: "/tmp/KiwiDesk-log.txt")),
    ]

    @Test("every problem is narrated, title and sentence")
    func everyProblemIsNarrated() {
        LocalizationManager.shared.select("en")
        for problem in problems {
            #expect(!LogExportText.title(for: problem).isEmpty)
            #expect(!LogExportText.sentence(for: problem).isEmpty)
        }
    }

    @Test("the write failure names the file, the tool failure hides stderr")
    func detailsAreRuled() {
        LocalizationManager.shared.select("en")
        let write = LogExportProblem(
            .writeFailed(URL(fileURLWithPath: "/x/KiwiDesk-log.txt"))
        )
        #expect(
            LogExportText.sentence(for: write).contains("KiwiDesk-log.txt")
        )
        let tool = LogExportProblem(
            .toolFailed(status: 64, stderr: "log: bad predicate")
        )
        #expect(!LogExportText.sentence(for: tool).contains("predicate"))
    }
}
