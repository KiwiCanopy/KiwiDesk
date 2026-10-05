import Foundation
import Testing

/// The plate slide's seams (#1956), held by spelling where no
/// fixture can see them.
@Suite("Plate slide seams (#1956)")
struct SpaceSlideSeamTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    /// Each live read the slide takes is pinned inert in both
    /// `makeTestCore` twins: the Reduce Motion read, or every
    /// suite's switch would hold its writes; the panel, or one is
    /// ordered in on the runner; the stack, a live WindowServer
    /// read per switch. `MachineTouchTests` holds the twins
    /// identical, which a deletion from both passes.
    @Test("both twins pin the slide's live reads")
    func bothTwinsPinTheReads() throws {
        let pins = [
            "core.spaceSlide.reduceMotion = { true }",
            "core.spaceSlide.present = { _ in }",
            "core.spaceSlide.stackOrder = { [:] }",
        ]
        for twin in ["KiwiDeskCoreTests", "KiwiDeskGuiTests"] {
            let source = try SourceScan.strippedSource(
                at: Self.root.appendingPathComponent(
                    "Tests/\(twin)/TestCore.swift"
                )
            )
            for pin in pins {
                #expect(source.contains(pin), "\(twin) misses \(pin)")
            }
        }
    }

    /// Both frame-write entry points of the applier stage a held
    /// window's write; a third entry point owes the same.
    @Test("every applier write path reaches the hold")
    func writePathsReachTheHold() throws {
        for function in ["apply", "applyInstant"] {
            let body = try SourceScan.functionBody(
                of: function,
                in: "FrameApplier.swift",
                under: "Tiling"
            )
            #expect(
                body.occurrences(of: "stageHeld(") == 1,
                "\(function) does not stage a held write"
            )
        }
    }
}
