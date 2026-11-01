import Foundation
import Testing

/// `pocket_app`'s production wirings no unit test reaches (#2612):
/// the GUI's chord hook, the keyed refusal's sound, and the
/// restart's reconcile, each pinned by exact count in its file.
@Suite("pocket_app stays wired (#2612)")
struct PocketAppSeamTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    private static let wirings: [(String, String, String, Int)] = [
        // The hook Core's keyed refusal reads its chord through.
        (
            "core.barMenuHooks.pocketKeyChord =",
            "Sources/KiwiDesk", "AppDelegate+BarMenus.swift", 1
        ),
        // The keyed refusal is sounded like every Pocket refusal.
        (
            "soundIfDrawn(",
            "Sources/KiwiDeskCore", "KiwiCore+PocketApp.swift", 1
        ),
        // A row gone since the capture unties at the restore.
        (
            "reconcilePocketKeys()",
            "Sources/KiwiDeskCore", "KiwiCore+Restore.swift", 1
        ),
    ]

    @Test("each wiring exists exactly as often as pinned, in its file")
    func wiringsArePinned() throws {
        for (needle, tree, file, count) in Self.wirings {
            let sites = try SourceScan.identifierSites(
                of: needle,
                under: Self.root.appendingPathComponent(tree)
            ).filter { $0.file.lastPathComponent == file }
            let found = sites.count
            #expect(
                found == count,
                "expected \(count)× `\(needle)` in \(file), found \(found)"
            )
        }
    }
}
