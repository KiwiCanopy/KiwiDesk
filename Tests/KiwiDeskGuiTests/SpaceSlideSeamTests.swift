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

    /// Every applier member that writes a frame stages a held
    /// window's write first — found by what it cannot avoid, the
    /// writer's frame call, so a new write path is caught by its
    /// write rather than by a list. The hold's own release, which
    /// performs the staged write, is the one member exempt.
    @Test("every applier write path reaches the hold")
    func writePathsReachTheHold() throws {
        let tiling = Self.root.appendingPathComponent(
            "Sources/KiwiDeskCore/Tiling"
        )
        let files = try FileManager.default.contentsOfDirectory(
            atPath: tiling.path
        ).filter { $0.hasPrefix("FrameApplier") && $0.hasSuffix(".swift") }
        var writers: [String] = []
        for file in files {
            let source = try SourceScan.strippedSource(
                at: tiling.appendingPathComponent(file)
            )
            for (name, body) in SourceScan.memberBodies(in: source)
            where body.contains("writer.setFrame(")
                || body.contains("writer.setPosition(")
            {
                writers.append(name)
                guard !Self.releases.contains(name) else { continue }
                #expect(
                    body.contains("stageHeld("),
                    "\(file) ▸ \(name) writes a frame without the hold"
                )
            }
        }
        // The scan must find the two entry points, or it read
        // nothing and passed for it.
        #expect(Set(writers).isSuperset(of: ["apply", "applyInstant"]))
    }

    /// The hold's release writes the frame it staged.
    private static let releases: Set<String> = ["write"]
}
