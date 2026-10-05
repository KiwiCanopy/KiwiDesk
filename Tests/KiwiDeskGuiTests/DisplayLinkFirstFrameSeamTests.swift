import Foundation
import Testing

/// `DisplayLinkFirstFrameTests` holds the first-frame step (#1878);
/// it reaches the springs only through `fire`, which no suite can
/// drive without a real `CADisplayLink`, so its routing is held here.
@Suite("Display link first-frame wiring (#1878)")
struct DisplayLinkFirstFrameSeamTests {
    /// The decision above reaches the springs only through `fire`.
    @Test("fire hands the step to the tick")
    func fireRoutesThroughStep() throws {
        let file = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDeskCore/OS/DisplayLink.swift"
            )
        let source = SourceScan.stripComments(
            try String(contentsOf: file, encoding: .utf8)
        )
        let start = try #require(source.range(of: "func fire("))
        let end = try #require(
            source.range(
                of: "static func step(",
                range: start.upperBound..<source.endIndex
            )
        )
        let body = String(source[start.upperBound..<end.lowerBound])
        let call = try #require(body.range(of: "Self.step("))
        // An early exit ahead of the step is the dropped tick.
        #expect(!body[..<call.lowerBound].contains("return"))
        #expect(body[call.lowerBound...].contains("last: lastTimestamp"))
        #expect(body.components(separatedBy: "onTick(").count == 2)
    }
}
