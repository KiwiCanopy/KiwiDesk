import Foundation
import Testing

/// Every later tour step's write of the live profile — the look and
/// the bars, and their Reverts — goes through
/// `OnboardingStartModel.writingProfile` (#3294), or the Spaces
/// step's preset copy reads as the user's edit and a Back return
/// replaces in place, leaving that copy behind.
@Suite("Tour profile writes take the copy's door (#3294)")
struct TourProfileWriteSeamTests {
    /// The Core writes a tour step makes to the live profile.
    private static let writes = [
        "core.paintShelf(",
        "core.restoreShelf(",
        "core.setBarVisibility(",
        "core.restoreBarVisibility(",
    ]

    /// How far above a write its `writingProfile {` may open: the
    /// door's block and the motion scope inside it.
    private static let reach = 3

    @Test("each tour write sits inside writingProfile")
    func writesTakeTheDoor() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk")
        var found = 0
        for url in try SourceScan.swiftSources(under: root)
        where url.lastPathComponent.hasPrefix("AppDelegate+Onboarding") {
            let lines = try SourceScan.strippedSource(at: url)
                .components(separatedBy: "\n")
            for (index, line) in lines.enumerated() {
                guard Self.writes.contains(where: line.contains) else {
                    continue
                }
                found += 1
                let above = lines[max(0, index - Self.reach)...index]
                #expect(
                    above.contains { $0.contains("writingProfile") },
                    Comment(
                        rawValue:
                            "\(url.lastPathComponent):\(index + 1) "
                            + "writes the live profile outside "
                            + "writingProfile"
                    )
                )
            }
        }
        // Non-vacuous: each of the four writes is wired once.
        #expect(found == Self.writes.count)
    }
}
