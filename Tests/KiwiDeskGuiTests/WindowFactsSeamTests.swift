import Foundation
import Testing

/// Float detection runs on one plain input, `WindowFacts` (#1883),
/// and every live producer builds it through `WindowFacts.read` —
/// `track`, the float recheck and the off-main list read. The
/// recorded-dump corpus replays the same body only while that
/// holds: a producer reading a fact beside the door, or detection
/// reading the element itself again, is a live input no dump can
/// carry, with every behaviour suite green. Scanned here because
/// `SourceScan` lives in the GUI test target (AGENTS.md §1).
@Suite("Window facts seam (#1883)")
struct WindowFactsSeamTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    /// Stripped Core source per file path under `KiwiDeskCore/`.
    private static func coreSources() throws -> [String: String] {
        let base = root.appendingPathComponent("Sources/KiwiDeskCore")
        var found: [String: String] = [:]
        for file in try SourceScan.swiftSources(under: base) {
            let key = String(
                file.path.dropFirst(base.path.count + 1)
            )
            found[key] = try SourceScan.strippedSource(at: file)
        }
        return found
    }

    private static func census(
        _ needle: String,
        in sources: [String: String]
    ) -> [String: Int] {
        sources.compactMapValues {
            let count = $0.occurrences(of: needle)
            return count > 0 ? count : nil
        }
    }

    @Test("every live producer reads its facts through the door")
    func producersTakeTheDoor() throws {
        let sources = try Self.coreSources()
        #expect(sources.count > 100, "the scan read too little")
        #expect(
            Self.census("WindowFacts.read(", in: sources) == [
                // `track`.
                "Events/EventLoop+Tracking.swift": 1,
                // The recheck's element, read only where nothing
                // forces the float.
                "Events/EventLoop+FloatVerdict.swift": 1,
                // The off-main list read (#1933).
                "Events/EventLoop+ListedWindows.swift": 1,
            ]
        )
        // Only the door assembles the value: a producer building
        // it by hand reads its facts beside the door.
        #expect(
            Self.census("WindowFacts(", in: sources) == [
                "AX/WindowFacts.swift": 1
            ]
        )
    }

    @Test("detection reads no element, and the door reads both")
    func detectionReadsFactsOnly() throws {
        let detection = try SourceScan.strippedSource(
            at: Self.root.appendingPathComponent(
                "Sources/KiwiDeskCore/AX/FloatDetection.swift"
            )
        )
        #expect(detection.contains("func autoFloatReason("))
        let reads = [
            "AXHelper.role(", "AXHelper.subrole(", "AXHelper.title(",
        ]
        for read in reads {
            #expect(!detection.contains(read), "detection calls \(read)")
        }
        let door = try SourceScan.functionBody(
            of: "read",
            in: "WindowFacts.swift",
            under: "AX"
        )
        #expect(door.contains("AXHelper.subrole(of: element)"))
        #expect(door.contains("AXHelper.title(of: element)"))
    }

    /// The live composition delegates to the pure one the corpus
    /// replays, rather than composing beside it.
    @Test("the live verdict is the composition the corpus replays")
    func liveVerdictDelegates() throws {
        let live = try SourceScan.functionBody(
            of: "autoFloatVerdict",
            in: "EventLoop+FloatVerdict.swift",
            under: "Events"
        )
        #expect(live.contains("Self.composeVerdict("))
        #expect(!live.contains("FloatDetection.autoFloatReason("))
        let pure = try SourceScan.functionBody(
            of: "composeVerdict",
            in: "EventLoop+FloatVerdict.swift",
            under: "Events"
        )
        #expect(pure.contains("FloatDetection.autoFloatReason("))
    }
}
