import Foundation
import Testing

/// Where Reduce transparency is READ, and where it re-renders
/// (#1374). The behaviour is `ReduceTransparencyTests`'; this
/// holds the wiring a behavioural test cannot see: that every
/// bar render takes the gate on its stored style and nothing
/// else, that the handler re-draws both bars, that the OS flag
/// has one home per tree, and that every glass fixture pins it.
@Suite("Reduce transparency seam (#1374)")
struct ReduceTransparencySeamTests {
    private static var root: URL {
        SourceScan.repoRoot(from: #filePath)
    }
    private static var core: URL {
        root.appendingPathComponent("Sources/KiwiDeskCore")
    }
    private static var gui: URL {
        root.appendingPathComponent("Sources/KiwiDesk")
    }
    private static var coreTests: URL {
        root.appendingPathComponent("Tests/KiwiDeskCoreTests")
    }

    /// Every type that hosts glass — found at the one decision
    /// point, `GlassHosting.resolve(`, Core-wide, never by a listed
    /// file — has a `render` that resolves its stored style
    /// through the gate exactly once and spells that stored style
    /// nowhere else in its body: a consumer reading it beside the
    /// copy draws the stored glass or alpha.
    @Test("each glass-hosting type renders through the gate, once")
    func rendersTakeTheGate() throws {
        let files = try SourceScan.swiftSources(under: Self.core)
        var sources: [URL: String] = [:]
        for file in files {
            sources[file] = try SourceScan.strippedSource(at: file)
        }
        // The hosts: the type each `GlassHosting.resolve(` call
        // site extends, read off its file's `extension` line.
        var hosts: Set<String> = []
        for (file, source) in sources
        where file.lastPathComponent != "GlassHosting.swift"
            && source.contains("GlassHosting.resolve(")
        {
            let type = try #require(
                source.range(of: "extension ").map { hit in
                    String(
                        source[hit.upperBound...]
                            .prefix { $0.isLetter || $0.isNumber }
                    )
                },
                Comment(
                    rawValue:
                        "\(file.lastPathComponent) resolves glass "
                        + "hosting outside an extension"
                )
            )
            hosts.insert(type)
        }
        // Two overlays host glass today; a shrunk roster reds.
        #expect(hosts.count >= 2, Comment(rawValue: "\(hosts.sorted())"))

        for host in hosts.sorted() {
            // The host's render: the one `func render(` among the
            // files declaring the type or extending it.
            let renders = sources.filter { file, source in
                (source.contains("class \(host)")
                    || source.contains("extension \(host) "))
                    && SourceScan.declarationBody(
                        after: "func render(",
                        in: source
                    ) != nil
            }
            #expect(
                renders.count == 1,
                Comment(
                    rawValue:
                        "\(host) declares render in "
                        + "\(renders.keys.map(\.lastPathComponent))"
                )
            )
            for (file, source) in renders {
                let name = file.lastPathComponent
                let body = try #require(
                    SourceScan.declarationBody(
                        after: "func render(",
                        in: source
                    )
                )
                let gate = SourceScan.callSites(
                    in: Array(body),
                    for: "LiquidGlassGate.rendered"
                )
                #expect(
                    gate.count == 1,
                    Comment(
                        rawValue:
                            "\(name): render resolves the style through "
                            + "LiquidGlassGate.rendered \(gate.count)×"
                    )
                )
                // The argument is the stored style; it appears once.
                let stored = try #require(
                    SourceScan.callArguments(
                        of: "LiquidGlassGate.rendered(",
                        in: body
                    )?.trimmingCharacters(in: .whitespaces),
                    Comment(rawValue: "\(name): the gate's argument")
                )
                #expect(
                    body.occurrences(of: stored) == 1,
                    Comment(
                        rawValue:
                            "\(name): `\(stored)` is read beside the "
                            + "gated copy — that reader draws the "
                            + "stored glass"
                    )
                )
            }
        }
    }

    /// The wired handler re-draws BOTH bars — through the one
    /// `updateBars` refresh, which builds both from one shelf plan;
    /// a handler that skipped it leaves the bars on stale glass
    /// until their next unrelated retile. Named, so
    /// `ReduceTransparencyTests` drives it.
    @Test("the handler re-renders both bars and the sticky marks")
    func handlerRerendersBothBars() throws {
        let source = try SourceScan.strippedSource(
            at: Self.core.appendingPathComponent(
                "App/KiwiCore+ReduceTransparency.swift"
            )
        )
        let handler = try #require(
            SourceScan.declarationBody(
                after: "func reduceTransparencyDidChange",
                in: source
            ),
            "the handler is gone"
        )
        for update in ["updateBars()", "updateStickyMarks()"] {
            #expect(
                handler.contains(update),
                Comment(rawValue: "the handler skips \(update)")
            )
        }
        let wiring = try #require(
            SourceScan.declarationBody(
                after: "func wireReduceTransparency",
                in: source
            )
        )
        #expect(wiring.contains("reduceTransparencyDidChange()"))
        #expect(wiring.contains("LiquidGlassGate.observe"))
        // Wired in `start()` and retired in `stop()`, the token
        // owned per core: a stopped core draws nothing, and an
        // init-time wiring retired by `stop()` never came back
        // on the re-grant's `start()` (code-reviewer, 2026-09-13).
        let boot = try SourceScan.strippedSource(
            at: Self.core.appendingPathComponent("App/KiwiCore+Boot.swift")
        )
        let start = try #require(
            SourceScan.declarationBody(after: "func start(", in: boot)
        )
        #expect(
            start.contains("wireReduceTransparency()"),
            "start() no longer wires the observer"
        )
        let lifecycle = try SourceScan.strippedSource(
            at: Self.core.appendingPathComponent(
                "App/KiwiCore+Lifecycle.swift"
            )
        )
        let stop = try #require(
            SourceScan.declarationBody(after: "func stop(", in: lifecycle)
        )
        #expect(
            stop.contains("retireReduceTransparency()"),
            "stop() no longer retires the observer"
        )
    }

    /// One reader of the OS flag in Core (`LiquidGlassGate`), and
    /// in the GUI an `allowed` map of who may read the environment
    /// value and why — a greying row reading it for its reason is
    /// the same OS value, not a second gate, and joins here with
    /// its reason; a second `glassGround` gate cannot.
    private static let allowedGuiReaders: [String: String] = [
        "GlassChrome.swift": "gates the glass branch",
        // The switch greys with its reason under the same OS
        // value — a grey, not a second gate on the branch
        // (#1418).
        "GlassCard.swift": "greys the Liquid Glass row with its reason",
    ]

    @Test("the OS flag has one home per tree")
    func oneReaderPerTree() throws {
        let coreReaders = try Self.files(
            under: Self.core,
            spelling: "accessibilityDisplayShouldReduceTransparency"
        )
        #expect(coreReaders == ["LiquidGlassGate.swift"])
        let guiReaders = try Self.files(
            under: Self.gui,
            spelling: "accessibilityReduceTransparency"
        )
        #expect(
            Set(guiReaders) == Set(Self.allowedGuiReaders.keys),
            Comment(
                rawValue:
                    "GUI readers \(guiReaders) vs allowed "
                    + "\(Self.allowedGuiReaders.keys.sorted()) — a "
                    + "reader joins with its reason"
            )
        )
        // Neither tree reaches across for the other's spelling.
        #expect(
            try Self.files(
                under: Self.gui,
                spelling: "accessibilityDisplayShouldReduceTransparency"
            ).isEmpty
        )
        #expect(
            try Self.files(
                under: Self.core,
                spelling: "accessibilityReduceTransparency"
            ).isEmpty
        )
    }

    /// The GUI reader gates the glass branch: the modifier reads
    /// the environment into a property, and `glassGround`'s
    /// `enabled:` argument is decided by that property. The SHAPE,
    /// not the spelling of the conjunction.
    @Test("GlassChrome gates the branch on the environment")
    func glassChromeGatesTheBranch() throws {
        let source = try SourceScan.strippedSource(
            at: Self.gui.appendingPathComponent(
                "Settings/Components/Common/GlassChrome.swift"
            )
        )
        let modifier = try #require(
            SourceScan.declarationBody(
                after: "struct GlassChrome",
                in: source
            ),
            "the GlassChrome modifier is gone"
        )
        let squashed = modifier.split(whereSeparator: \.isWhitespace)
            .joined()
        // Read off the unsquashed body: squashing erases the
        // boundary that ends the property's name.
        let pattern = try NSRegularExpression(
            pattern:
                #"@Environment\(\\\.accessibilityReduceTransparency\)"#
                + #"\s*(?:private\s+)?var\s+([A-Za-z_]+)"#
        )
        let range = NSRange(modifier.startIndex..., in: modifier)
        let property = try #require(
            pattern.firstMatch(in: modifier, range: range)
                .flatMap { Range($0.range(at: 1), in: modifier) }
                .map { String(modifier[$0]) },
            "GlassChrome no longer reads the environment"
        )
        let arguments = try #require(
            SourceScan.callArguments(of: "glassGround(", in: squashed),
            "GlassChrome no longer calls glassGround"
        )
        // The WIRING: `glassChrome(in:)` applies the modifier, and
        // the ground has no other caller — a modifier nobody
        // applies is a correctly gated dead end (guard-prover,
        // 2026-09-13).
        let entry = try #require(
            SourceScan.declarationBody(
                after: "func glassChrome",
                in: source
            )
        )
        #expect(
            entry.contains("modifier(GlassChrome("),
            "glassChrome no longer applies the GlassChrome modifier"
        )
        #expect(
            SourceScan.callSites(in: Array(source), for: ".glassGround")
                .count == 1,
            "glassGround is called from more than the modifier"
        )
        // Polarity is the decision, not a retunable value: the
        // property NEGATED is what stands the branch down.
        #expect(
            arguments.contains("enabled:")
                && arguments.contains("!\(property)"),
            Comment(
                rawValue:
                    "glassGround's enabled: is not stood down by "
                    + "!\(property): \(arguments)"
            )
        )
    }

    /// Every Core fixture that renders glass pins the OS read off
    /// in `init`, or it passes on a developer's machine with the
    /// setting off and fails on one with it on (#660). Found by
    /// what the file touches, never by a list.
    @Test("every glass fixture pins the OS read")
    func glassFixturesPinTheRead() throws {
        var fixtures = 0
        for file in try SourceScan.swiftSources(under: Self.coreTests) {
            let source = try SourceScan.strippedSource(at: file)
            guard
                ["glassPlate", "boxGlasses", "GlassTint.apply(", "glassRun"]
                    .contains(where: source.contains)
            else { continue }
            fixtures += 1
            #expect(
                source.contains("LiquidGlassGate.override"),
                Comment(
                    rawValue:
                        "\(file.lastPathComponent) renders glass and "
                        + "never pins LiquidGlassGate.override"
                )
            )
        }
        // 4 since #1517: the churn suite no longer drives a glass
        // run, the shelf's plate never hosting a view.
        #expect(fixtures >= 4, Comment(rawValue: "\(fixtures) fixtures"))
    }

    private static func files(
        under root: URL,
        spelling: String
    ) throws -> [String] {
        try SourceScan.swiftSources(under: root)
            .filter { file in
                try SourceScan.strippedSource(at: file).contains(spelling)
            }
            .map { $0.lastPathComponent }
            .sorted()
    }
}
