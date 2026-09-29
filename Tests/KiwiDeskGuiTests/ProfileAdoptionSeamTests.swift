import Foundation
import Testing

/// The live profile's two adoption records move together (#1518):
/// `ActiveProfile` and the saved-modes record are set in the one
/// `adopt(_:)`, so no door that makes a profile live can set one
/// and leave the other answering for the profile before it. No
/// behaviour can reach that state from outside `ProfileManager`
/// today, so the shape is what is pinned: every assignment of a
/// profile to `active` is `adopt`'s own.
@Suite("Profile adoption seam")
struct ProfileAdoptionSeamTests {
    @Test("only adopt makes a profile live")
    func oneAdoptionDoor() throws {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDeskCore/Profiles/ProfileManager.swift"
            )
        let source = SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        )
        let assignment = "active = ActiveProfile("
        #expect(source.components(separatedBy: assignment).count == 2)
        let adopt = try #require(
            SourceScan.declarationBody(
                after: "private func adopt(",
                in: source
            )
        )
        #expect(adopt.contains(assignment))
        #expect(adopt.contains("savedModesRecord = "))
    }
}
