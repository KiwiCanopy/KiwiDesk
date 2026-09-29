import Foundation
import Testing

/// Both bars stand down through the one
/// `KiwiCore.shelfStandsDown(on:)` — a native-fullscreen Space
/// (#670) or a presentation in front (#1787). A bar surface
/// gating on `currentSpaceIsUser(display:` beside it would hide
/// on the first and draw over a slide show, so that read has one
/// home in Core: the stand-down itself.
@Suite("Shelf stand-down seam (#1787)")
struct ShelfStandDownSeamTests {
    @Test("the per-display user-space read lives in the stand-down")
    func userSpaceReadHasOneHome() throws {
        let core = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore")
        var homes: [String: Int] = [:]
        let files = try FileManager.default.subpathsOfDirectory(
            atPath: core.path
        )
        .filter { $0.hasSuffix(".swift") }
        #expect(!files.isEmpty)
        for file in files {
            let source = SourceScan.stripComments(
                try String(
                    contentsOf: core.appendingPathComponent(file),
                    encoding: .utf8
                )
            )
            // Whitespace out, so a call wrapped before `display:`
            // still counts; the declaration is subtracted, since
            // it reads the same once squeezed.
            let squeezed = source.filter { !$0.isWhitespace }
            func hits(_ needle: String) -> Int {
                squeezed.components(separatedBy: needle).count - 1
            }
            let count =
                hits("currentSpaceIsUser(display:")
                - hits("funccurrentSpaceIsUser(display:")
            if count > 0 { homes[file] = count }
        }
        #expect(homes == ["App/KiwiCore+ScreenCovering.swift": 1])
    }
}
