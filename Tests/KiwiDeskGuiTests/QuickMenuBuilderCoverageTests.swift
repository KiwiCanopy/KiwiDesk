import Foundation
import Testing

@testable import KiwiDesk

/// No file builds menu rows without joining a list (#802).
///
/// Split from `LayoutMenuEnablementScanTests` at §2.1's ceiling,
/// and the seam is real: that suite asks whether the rows in a
/// CHECKED file state their enablement, this asks whether every
/// file that builds rows is checked at all. The second question is
/// the one that survives a file split, and it is why the lists live
/// in `QuickMenuBuilders` rather than in either suite.
@Suite("Every menu-row builder is accounted for (#802)")
struct QuickMenuBuilderCoverageTests {
    /// **Coverage over the TREE, not over the list**, which is the
    /// only shape that catches a split.
    ///
    /// Asserting the listed files still build rows does not: after
    /// `screenItem` moves to its own file, the original still
    /// builds plenty and the suite stays green while half the rows
    /// go unchecked. This asks the opposite question — is there any
    /// file building rows that no list names — so a new file lands
    /// in neither and reds (`architect-reviewer`, 2026-08-17,
    /// raised twice before it was fixed at the right altitude).
    @Test("No file builds menu rows without joining a list")
    func everyRowBuilderIsAccountedFor() throws {
        let root = SourceScan.repoRoot(from: #filePath)
        let tree = try SourceScan.swiftSources(
            under: root.appendingPathComponent("Sources/KiwiDesk")
        )
        let named =
            Set(
                QuickMenuBuilders.checked.map {
                    ($0 as NSString).lastPathComponent
                }
            )
            .union(QuickMenuBuilders.unchecked.keys)
        var found = 0
        for file in tree {
            let text = SourceScan.blankingCommentsAndLiterals(
                try String(contentsOf: file, encoding: .utf8)
            )
            guard text.contains("NSMenuItem(") else { continue }
            found += 1
            #expect(
                named.contains(file.lastPathComponent),
                Comment(
                    rawValue:
                        "\(file.lastPathComponent) constructs "
                        + "NSMenuItem and is in neither `builders` "
                        + "nor `knownUnchecked` — a menu builder "
                        + "outside both lists is exempt from the "
                        + "#802 check by accident"
                )
            )
        }
        // Assert the scan found its input before asserting about
        // it: an enumerator over a renamed tree yields nothing and
        // every check above passes for having looked at nothing.
        #expect(found >= QuickMenuBuilders.checked.count)
    }

}
