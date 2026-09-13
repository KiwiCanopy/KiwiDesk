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

    /// Every bar render — found by what it does, hosting glass,
    /// rather than by a listed file — resolves its stored style
    /// through the gate exactly once, and spells that stored
    /// style nowhere else in its body: a consumer reading it
    /// beside the copy draws the stored glass or alpha.
    @Test("each bar render takes the gate on its stored style, once")
    func rendersTakeTheGate() throws {
        var renders = 0
        for file in try SourceScan.swiftSources(
            under: Self.core.appendingPathComponent("Bar")
        ) {
            let source = try SourceScan.strippedSource(at: file)
            guard let declaration = source.range(of: "func render("),
                let body = SourceScan.declarationBody(
                    after: "func render(",
                    in: source
                ),
                body.contains("glassHosting(")
            else { continue }
            _ = declaration
            renders += 1
            let name = file.lastPathComponent
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
                        "\(name): `\(stored)` is read beside the gated "
                        + "copy — that reader draws the stored glass"
                )
            )
        }
        // Two overlays host glass today; a shrunk roster reds.
        #expect(renders >= 2, "fewer than two glass-hosting renders")
    }

    /// The wired handler re-draws BOTH bars; a handler that forgot
    /// one leaves that bar on stale glass until its next unrelated
    /// retile. Named, so `ReduceTransparencyTests` drives it.
    @Test("the handler re-renders both bars")
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
        for update in ["updateAppBar()", "updateSpaceBar()"] {
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
        let bootstrap = try SourceScan.strippedSource(
            at: Self.core.appendingPathComponent(
                "App/KiwiCore+Bootstrap.swift"
            )
        )
        #expect(
            bootstrap.contains("wireReduceTransparency()"),
            "bootstrap no longer wires the observer"
        )
    }

    /// One reader of the OS flag in Core (`LiquidGlassGate`), and
    /// in the GUI an `allowed` map of who may read the environment
    /// value and why — a greying row reading it for its reason is
    /// the same OS value, not a second gate, and joins here with
    /// its reason; a second `glassGround` gate cannot.
    private static let allowedGuiReaders: [String: String] = [
        "GlassChrome.swift": "gates the glass branch"
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
        #expect(
            arguments.contains("enabled:")
                && arguments.contains(property),
            Comment(
                rawValue:
                    "glassGround's enabled: is not decided by "
                    + "\(property): \(arguments)"
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
        #expect(fixtures >= 5, Comment(rawValue: "\(fixtures) fixtures"))
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
