import Foundation
import Testing

/// An app's Pocket key row has one spelling and one reader (#2612
/// ▸ 6): `PocketAppLuaArg` writes and reads `KiwiDesk.pocket_app`,
/// and every other file in both trees goes through it, so the GUI's
/// rows, KiwiHub and Core can never read the row two ways. The
/// needle is the call's prefix without its paren, so a matcher
/// reading the prefix alone reds too; the bare verb `pocket_app`,
/// which dispatch and the API records spell, it leaves alone.
/// Disclosed limit: a needle split by concatenation passes.
@Suite("Pocket key row matcher seam")
struct PocketAppMatcherSeamTests {
    private let needle = "KiwiDesk.pocket_app"

    /// Repo-relative path -> how many times it may spell the call.
    private let allowed = [
        "Sources/KiwiDeskCore/Config/PocketAppLuaArg.swift": 1
    ]

    @Test("only PocketAppLuaArg spells the call")
    func oneSpelling() throws {
        let root = SourceScan.repoRoot(from: #filePath)
        let prefix = root.path + "/"
        var counts: [String: Int] = [:]
        for tree in ["KiwiDesk", "KiwiDeskCore"] {
            let dir = root.appendingPathComponent("Sources")
                .appendingPathComponent(tree)
            let files = try SourceScan.swiftSources(under: dir)
            #expect(files.count > 50)
            for file in files {
                let source = SourceScan.stripComments(
                    try String(contentsOf: file, encoding: .utf8)
                )
                let hits = source.occurrences(of: needle)
                guard hits > 0 else { continue }
                counts[String(file.path.dropFirst(prefix.count))] = hits
            }
        }
        #expect(counts == allowed)
    }
}
