import Foundation
import Testing

/// The raise gate's on-screen read asks SkyLight one window at a
/// time before the public list (#2634), whose read waits on this
/// process's pending window updates while holding the WindowServer
/// connection lock (#2531). Ordered in alone is not the flag, and a
/// window ordered out has no public entry the gate abstains on, so
/// the SkyLight answer is only taken for a window ordered in.
@Suite("Raise gate on-screen read seam (#2634)")
struct RaiseGateOnScreenSeamTests {
    private static var core: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore")
    }

    private static func body(
        _ declaration: String,
        in file: String
    ) throws -> String {
        let text = try SourceScan.strippedSource(
            at: core.appendingPathComponent(file)
        )
        return String(
            try #require(
                SourceScan.declarationBody(after: declaration, in: text),
                "\(declaration) is gone"
            )
        )
    }

    @Test("isOnScreen asks SkyLight before the public list")
    func skyLightAnswersFirst() throws {
        let body = try Self.body(
            "static func isOnScreen(",
            in: "AX/FloatDetection.swift"
        )
        let sky = try #require(
            body.range(of: "SkyLight.windowOnScreen(")
        )
        let list = try #require(body.range(of: "WindowListRead.copy("))
        #expect(sky.lowerBound < list.lowerBound)
    }

    @Test("the visible read is taken only for a window ordered in")
    func visibleNeedsOrderedIn() throws {
        let body = try Self.body(
            "static func windowOnScreen(",
            in: "OS/SkyLight+WindowVisibility.swift"
        ).filter { !$0.isWhitespace }
        let guarded = try #require(
            body.range(
                of: "guardwindowOrderedIn(wid)==trueelse{returnnil}"
            )
        )
        let visible = try #require(body.range(of: "windowVisible(wid)"))
        #expect(guarded.upperBound <= visible.lowerBound)
    }
}
