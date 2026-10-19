import Foundation
import Testing

/// The #446 display follow asks the Dock hit test before it
/// switches. `DisplayFollowDockTests` holds the predicate; no
/// fixture can drive the follow itself, which reads the host's
/// real screens, so the call site is pinned here.
@Suite("The display follow asks the Dock hit test")
struct DisplayFollowDockWiringTests {
    private static let file = SourceScan.repoRoot(from: #filePath)
        .appendingPathComponent(
            "Sources/KiwiDeskCore/Commands/KiwiCore+DisplayFocus.swift"
        )

    @Test("The hit test reads the front stack ahead of the switch")
    func hitTestPrecedesTheSwitch() throws {
        let source = try SourceScan.strippedSource(at: Self.file)
        let body = try #require(
            SourceScan.declarationBody(
                after: "func followDisplayUnderClick(",
                in: source
            )
        )
        let arguments = try #require(
            SourceScan.callArguments(of: "pressHitsDock(", in: body)
        )
        #expect(arguments.contains("frontStack()"))
        let test = try #require(body.range(of: "pressHitsDock("))
        let refusal = try #require(
            body.range(
                of: "else { return }",
                range: test.upperBound..<body.endIndex
            )
        )
        let guardStart = try #require(
            body.range(
                of: "guard",
                options: .backwards,
                range: body.startIndex..<test.lowerBound
            )
        )
        #expect(
            body[guardStart.upperBound..<test.lowerBound]
                .filter { !$0.isWhitespace } == "!Self."
        )
        let switchCall = try #require(
            body.range(of: "applyFocusedSpaceSwitch(")
        )
        #expect(refusal.upperBound <= switchCall.lowerBound)
    }
}
