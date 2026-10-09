import Foundation
import Testing

/// A bar's edge is written through the `ScreenEdged` doors and read
/// resolved for a screen (#1948). Writes: a raw `.edge =`, an
/// `edgeOverride` write, a two-way `$…Style.edge` binding or a
/// key-path write beside the doors could leave an entry equal to
/// the bar's edge, skip the collapse, or keep a screen's own edge a
/// pick of the bar's edge must clear. Reads: `barEdges(space:app:)`
/// and the GUI's readers of a bar's own edge answer for no screen.
/// Both trees are scanned; a hit outside its map reds until it
/// routes through a door or names its reason here.
@Suite("Bar edge write census (#1948)")
struct BarEdgeWriteCensusTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    /// File → (raw writes it holds, why).
    private static let allowed: [String: (Int, String)] = [
        "ScreenEdged.swift": (4, "the doors themselves"),
        "ShelfEdge.swift": (1, "`ShelfEdge`'s own field, no bar's"),
        "AppBarStyle+Coding.swift": (3, "its coding key and decoder"),
        "SpaceBarStyle+Coding.swift": (3, "its coding key and decoder"),
        "KiwiCore+ShelfPaint.swift": (
            2,
            "a Revert puts back the entries a look left alone"
        ),
    ]

    private static func regexes(_ patterns: [String]) -> [NSRegularExpression]
    {
        patterns.map { try! NSRegularExpression(pattern: $0) }
    }

    private static let writes = regexes([
        #"\.edge\s*=(?!=)"#,
        #"\bedgeOverride(\[[^\]]*\])?\s*=(?!=)"#,
        #"\$[\w.]*Style\.edge\b"#,
        // A key path handed to `map` reads; any other may write.
        #"(?<!map\()\\[\w.]*\.edge(Override)?\b"#,
    ])

    /// A bare `edge =` — scanned in the two styles' own files,
    /// where the stored property is in scope unqualified.
    private static let bareWrite = regexes([#"(?<![.\w])edge\s*=(?!=)"#])

    private static func count(
        _ regexes: [NSRegularExpression],
        in text: String
    ) -> Int {
        let range = NSRange(text.startIndex..., in: text)
        return regexes.reduce(0) {
            $0 + $1.numberOfMatches(in: text, range: range)
        }
    }

    private func sources(_ dirs: [String]) throws -> [URL] {
        let files = try dirs.flatMap {
            try SourceScan.swiftSources(
                under: Self.root.appendingPathComponent($0)
            )
        }
        #expect(files.count > 100)
        return files
    }

    private func census(
        in dirs: [String],
        _ hits: (String, String) -> Int
    ) throws -> [String: Int] {
        var found: [String: Int] = [:]
        for file in try sources(dirs) {
            let name = file.lastPathComponent
            let count = hits(name, try SourceScan.strippedSource(at: file))
            guard count > 0 else { continue }
            found[name, default: 0] += count
        }
        return found
    }

    @Test("every raw bar-edge write is a door or a named exemption")
    func rawWritesAreCensused() throws {
        let found = try census(
            in: ["Sources/KiwiDeskCore", "Sources/KiwiDesk"]
        ) { name, text in
            let style =
                name.hasPrefix("AppBarStyle")
                || name.hasPrefix("SpaceBarStyle")
            return Self.count(Self.writes, in: text)
                + (style ? Self.count(Self.bareWrite, in: text) : 0)
        }
        #expect(found == Self.allowed.mapValues(\.0))
    }

    /// `barEdges(space:app:)` reads each bar's raw `edge`: a
    /// caller hands it settings already resolved for one screen
    /// (`TilingSettings.onScreen(_:)`), or names why it may read
    /// the bars' own edges.
    private static let foldCallers: [String: (Int, String)] = [
        "TilingSettings+Shelf.swift": (
            2,
            "the declaration, and `shelfEdges(in:on:)` over onScreen"
        ),
        "KiwiCore+ShelfPlan.swift": (
            1,
            "`updateBars()` hands it each display's onScreen copy"
        ),
        "HomeCardPlate+Bars.swift": (1, pictureDeferral),
    ]

    /// Settings readers of a bar's own edge (or of the bars'
    /// shared one) that answer for no screen.
    private static let guiReaders: [String: (Int, String)] = [
        "SettingsValueReadout+KiwiShelf.swift": (
            4,
            "the bar rows' readout narrates the bar's own level"
        ),
        "SettingKey+KiwiShelf.swift": (3, keySpelling),
        "SettingKeyMasterWrites.swift": (2, keySpelling),
        "HomeCardPlate+Bars.swift": (2, pictureDeferral),
        "HomeCardContent.swift": (
            5,
            "the Home card's caption names the bars' own edges "
                + "until the Per screen rows land (#1948 PR 2)"
        ),
        "BarsGates.swift": (
            1,
            "order and minimum grey on the bars' own split; "
                + "per screen they are PR 2's (#1948)"
        ),
        "AdvancedColorsGates.swift": (
            1,
            "the front-app colour's gate reads the Space Bar's "
                + "own edge; per screen it is PR 2's (#1948)"
        ),
    ]

    private static let pictureDeferral =
        "the Home card pictures the bars' own edges until the "
        + "Per screen rows land (#1948 PR 2)"
    private static let keySpelling = "a census key's spelling"

    private static let guiReader = regexes([
        #"sharedBarEdge"#,
        #"\b(spaceBarStyle|appBarStyle|style)\.edge\b"#,
    ])

    @Test("every barEdges caller is resolved for a screen or named")
    func foldCallersAreCensused() throws {
        let found = try census(
            in: ["Sources/KiwiDeskCore", "Sources/KiwiDesk"]
        ) { _, text in
            text.components(separatedBy: "barEdges(").count - 1
        }
        #expect(found == Self.foldCallers.mapValues(\.0))
    }

    @Test("every Settings reader of a bar's own edge is named")
    func guiReadersAreCensused() throws {
        let found = try census(in: ["Sources/KiwiDesk"]) { _, text in
            Self.count(Self.guiReader, in: text)
        }
        #expect(found == Self.guiReaders.mapValues(\.0))
    }
}
