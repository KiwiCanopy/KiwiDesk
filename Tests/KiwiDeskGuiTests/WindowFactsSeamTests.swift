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
        let reads = ["role(of:", "subrole(of:", "title(of:", "attribute("]
        for read in reads {
            #expect(!bodies.contains(read), "detection calls \(read)")
        }
        // No element at all: the one left is `hasNativeTabs`'s own
        // parameter, whose body the strip above removed.
        #expect(bodies.occurrences(of: "AXUIElement") == 1)
    }

    /// A facts value handed to detection or the composition is
    /// never assembled in the call: an `AXHelper.` read or a bare
    /// `.init(` there is a fact read beside the door, which the
    /// spelled-type census above cannot see.
    @Test("no detection call reads its facts in the argument list")
    func noFactsBuiltInTheCall() throws {
        let sources = try Self.coreSources()
        var calls = 0
        for (file, source) in sources {
            let text = Array(source)
            for needle in ["autoFloatReason(", "composeVerdict("] {
                for args in Self.arguments(of: needle, in: text) {
                    calls += 1
                    for read in ["AXHelper.", ".init("] {
                        #expect(
                            !args.contains(read),
                            "\(file): \(needle) reads \(read)"
                        )
                    }
                }
            }
        }
        // The declarations, the live composition's call and the
        // producers' detection calls, at the least.
        #expect(calls >= 5, "found \(calls) calls")
    }

    /// Each balanced argument list following `needle` in `text`.
    private static func arguments(
        of needle: String,
        in text: [Character]
    ) -> [String] {
        let marker = Array(needle)
        var found: [String] = []
        var index = 0
        while index + marker.count <= text.count {
            guard Array(text[index..<(index + marker.count)]) == marker
            else {
                index += 1
                continue
            }
            var cursor = index + marker.count - 1
            if let args = SourceScan.balanced(
                text,
                from: &cursor,
                open: "(",
                close: ")"
            ) {
                found.append(args)
            }
            index += marker.count
        }
        return found
    }

    /// The live trait read takes the one button fold the corpus
    /// loader takes, so a fold copied back beside it reds here
    /// rather than leaving the corpus on a rule nothing runs.
    @Test("the live trait read folds its buttons through the one fold")
    func traitsTakeTheFold() throws {
        let traits = try SourceScan.functionBody(
            of: "windowTraits",
            in: "AXHelper+WindowTraits.swift",
            under: "AX"
        )
        #expect(traits.contains("WindowTraits.titlebarButton(from:"))
        #expect(!traits.contains("contains(true)"))
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
        // Terminated, so a value built on the live read does not
        // pass for the read itself.
        let inputs = [
            #"activationPolicy:\s*policy\(of:\s*pid\)\s*,"#,
            #"tilesAsOwnWindow:\s*tilesAsOwnWindow\(pid:\s*pid,"#
                + #"\s*id:\s*id\)\s*,"#,
            #"rules:\s*floatRules\s*\)"#,
        ]
        for input in inputs {
            #expect(
                live.range(of: input, options: .regularExpression)
                    != nil,
                "autoFloatVerdict no longer hands \(input)"
            )
        }
        #expect(!live.contains("FloatDetection.autoFloatReason("))
        let pure = try SourceScan.functionBody(
            of: "composeVerdict",
            in: "EventLoop+FloatVerdict.swift",
            under: "Events"
        )
        #expect(pure.contains("FloatDetection.autoFloatReason("))
    }
}
