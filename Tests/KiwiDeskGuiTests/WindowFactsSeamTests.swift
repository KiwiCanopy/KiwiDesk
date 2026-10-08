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
        // it by hand reads its facts beside the door, in any of
        // the spellings an initializer takes.
        #expect(
            Self.census("WindowFacts(", in: sources) == [
                "AX/WindowFacts.swift": 1
            ]
        )
        #expect(Self.census("WindowFacts.init(", in: sources) == [:])
        let typedInit = #"WindowFacts\s*=\s*\.init\("#
        for (file, source) in sources {
            #expect(
                source.range(of: typedInit, options: .regularExpression)
                    == nil,
                "\(file) builds WindowFacts through .init("
            )
        }
    }

    /// The title is a round trip on a live window: the door
    /// defers it into the closure detection asks only where
    /// structure tiles (`WindowFactsTests` holds the asking).
    @Test("the door reads role and subrole, and defers the title")
    func doorDefersTheTitle() throws {
        let door = try SourceScan.functionBody(
            of: "read",
            in: "WindowFacts.swift",
            under: "AX"
        )
        #expect(door.contains("AXHelper.subrole(of: element)"))
        #expect(door.contains("{ AXHelper.title(of: element) }"))
        #expect(door.occurrences(of: "AXHelper.title(") == 1)
    }

    /// Every `FloatDetection*` file, qualified or not (an
    /// `extension AXHelper` spells the reads bare), save
    /// `hasNativeTabs`, which reads children's roles for the tab
    /// reconciler and is no part of detection.
    @Test("detection reads no element")
    func detectionReadsFactsOnly() throws {
        let base = Self.root.appendingPathComponent(
            "Sources/KiwiDeskCore/AX"
        )
        let files = try SourceScan.swiftSources(under: base).filter {
            $0.lastPathComponent.hasPrefix("FloatDetection")
        }
        #expect(files.count >= 2, "scanned \(files.count) files")
        let tabs = try SourceScan.functionBody(
            of: "hasNativeTabs",
            in: "FloatDetection.swift",
            under: "AX"
        )
        try #require(tabs.contains("role(of: $0)"))
        var bodies = ""
        for file in files {
            bodies += try SourceScan.strippedSource(at: file)
                .replacingOccurrences(of: tabs, with: "")
        }
        #expect(bodies.contains("func autoFloatReason("))
        for read in ["role(of:", "subrole(of:", "title(of:"] {
            #expect(!bodies.contains(read), "detection calls \(read)")
        }
    }

    @Test("track hands its facts, and only the recheck an element")
    func trackHandsItsFacts() throws {
        let track = try SourceScan.functionBody(
            of: "track",
            in: "EventLoop+Tracking.swift",
            under: "Events"
        )
        #expect(track.contains(".facts(facts)"))
        #expect(!track.contains(".element("))
        let sources = try Self.coreSources()
        #expect(
            Self.census(".element(", in: sources)[
                "Events/EventLoop+Tracking.swift"
            ] == 1
        )
        let recheck = try SourceScan.functionBody(
            of: "recheckFloat",
            in: "EventLoop+Tracking.swift",
            under: "Events"
        )
        #expect(recheck.contains(".element(element, layer:"))
    }

    /// The live composition delegates to the pure one the corpus
    /// replays, handing it the loop's own rules, the app's policy
    /// and the own-window mark rather than composing beside it.
    @Test("the live verdict is the composition the corpus replays")
    func liveVerdictDelegates() throws {
        let live = try SourceScan.functionBody(
            of: "autoFloatVerdict",
            in: "EventLoop+FloatVerdict.swift",
            under: "Events"
        )
        #expect(live.contains("Self.composeVerdict("))
        #expect(live.contains("activationPolicy: policy(of: pid)"))
        let mark = "tilesAsOwnWindow: tilesAsOwnWindow(pid: pid, id: id)"
        #expect(live.contains(mark))
        #expect(live.contains("rules: floatRules"))
        #expect(!live.contains("FloatDetection.autoFloatReason("))
        let pure = try SourceScan.functionBody(
            of: "composeVerdict",
            in: "EventLoop+FloatVerdict.swift",
            under: "Events"
        )
        #expect(pure.contains("FloatDetection.autoFloatReason("))
    }
}
