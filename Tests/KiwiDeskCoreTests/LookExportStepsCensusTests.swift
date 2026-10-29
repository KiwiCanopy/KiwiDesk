import Foundation
import Testing

@testable import KiwiDeskCore

/// The look file's in-memory crossing keeps pace with the library
/// (#1740): a `LookDocument.currentFormat` bump is how a look-path
/// rename reaches `looks.json`, so the file's crossing must lift to
/// that format too, or an older file loses that styling on import.
@Suite("Look export steps census")
struct LookExportStepsCensusTests {
    @Test("the crossing lifts to the current look format")
    func liftsToCurrentFormat() {
        let top = ConfigMigration.lookExportSteps.map(\.to).max()
        #expect(top == LookDocument.currentFormat)
    }

    @Test("entries lift in order, each to a format of its own")
    func entriesAreOrdered() {
        let targets = ConfigMigration.lookExportSteps.map(\.to)
        #expect(targets == targets.sorted())
        #expect(Set(targets).count == targets.count)
    }

    @Test("a file at a format skips the steps below it")
    func formatSkipsOlderSteps() throws {
        let file = """
            {"format": 2,
             "look": {"name": "Odd",
                      "style": {"animations.on_shelf": false},
                      "colors": {}}}
            """
        let crossed = ConfigMigration.crossingLookExport(
            Data(file.utf8),
            from: 2
        )
        #expect(String(decoding: crossed, as: UTF8.self) == file)
    }
}
