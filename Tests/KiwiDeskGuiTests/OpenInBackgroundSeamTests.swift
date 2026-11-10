import Foundation
import Testing

/// Where `open_in_background`'s report door sits (#3141), which no
/// behavioural test can red on: ahead of the #1161 re-assert, whose
/// direct raise would take the first take and report unintended,
/// and behind the self-echo drop, so a raise of ours is never
/// handed back. The call count is `LaunchFollowSeamTests`'.
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
}
