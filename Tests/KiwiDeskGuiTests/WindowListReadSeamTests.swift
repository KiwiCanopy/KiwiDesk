import Foundation
import Testing

/// The public window list has one door (#2634): every read names
/// its call site through `WindowListRead.copy`, so a slow read is
/// attributed in the log. A bare call beside it reads unnamed.
@Suite("Window-list read door (#2634)")
struct WindowListReadSeamTests {
    private static var core: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore")
    }

    @Test("only the door calls CGWindowListCopyWindowInfo")
    func oneDoor() throws {
        var callers: [String: Int] = [:]
        let files = try SourceScan.swiftSources(under: Self.core)
        #expect(!files.isEmpty)
        for file in files {
            let text = try SourceScan.strippedSource(at: file)
            let hits =
                text.components(
                    separatedBy: "CGWindowListCopyWindowInfo("
                ).count - 1
            if hits > 0 { callers[file.lastPathComponent] = hits }
        }
        #expect(callers == ["WindowListRead.swift": 1])
    }
}
