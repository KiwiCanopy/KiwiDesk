import Foundation
import Testing

/// Where `open_in_background`'s report door sits (#3141), which no
/// behavioural test can red on: ahead of the #1161 re-assert, whose
/// direct raise would take the first take and report unintended,
/// and behind the self-echo drop, so a raise of ours is never
/// handed back. The call count is `LaunchFollowSeamTests`'; the
/// hold writes' closure is here.
@Suite("open_in_background's report door order (#3141)")
struct OpenInBackgroundSeamTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    @Test("the door sits between the self-echo drop and #1161")
    func doorOrder() throws {
        let handler = try SourceScan.strippedSource(
            at: Self.root.appendingPathComponent(
                "Sources/KiwiDeskCore/App/KiwiCore+FocusEvents.swift"
            )
        )
        let echo = try #require(handler.range(of: "self-echo dropped"))
        let door = try #require(
            handler.range(of: "handBackBackgroundFocus(")
        )
        let bounce = try #require(
            handler.range(of: "reassertAgainstPlacementBounce(")
        )
        #expect(echo.lowerBound < door.lowerBound)
        #expect(door.lowerBound < bounce.lowerBound)
    }

    /// `LaunchFollowSeamTests` pins each hold write by its argument;
    /// this closes the set, so a third note or lift spelled with
    /// another argument cannot go unseen (#3497).
    @Test("a hold is noted and lifted only where pinned")
    func holdWritesAreClosed() throws {
        let core = Self.root.appendingPathComponent("Sources/KiwiDeskCore")
        let pinned: [(String, Set<String>)] = [
            (
                "holds.note(",
                [
                    "KiwiCore+OpenInBackground.swift",
                    "KiwiCore+VisionAutoOpen.swift",
                ]
            ),
            (
                "holds.lift(",
                [
                    "LaunchFollowIntent.swift",
                    "KiwiCore+VisionAutoOpen.swift",
                ]
            ),
        ]
        for (needle, files) in pinned {
            let sites = try SourceScan.identifierSites(
                of: needle,
                under: core
            )
            let found = Set(sites.map(\.file.lastPathComponent))
            #expect(
                sites.count == files.count && found == files,
                """
                expected `\(needle)` once in each of \(files.sorted()), \
                found: \(sites.map(\.site).joined(separator: ", "))
                """
            )
        }
    }
}
