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
/// routes through a door or names its reason here. Blind spots,
/// review's: a bare `edge =` is scanned only in the two styles'
/// own files, and a write through a generic `[keyPath:]` whose
/// key path is built elsewhere is not seen.
@Suite("Bar edge write census (#1948)")
struct BarEdgeWriteCensusTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    /// File → (raw writes it holds, why).
    private static let allowed: [String: (Int, String)] = [
        "ScreenEdged.swift": (4, "the doors themselves"),
        "ShelfEdge.swift": (1, "`ShelfEdge`'s own field, no bar's"),
        "ShelfRevealer+Target.swift": (
            1, "`ShelfRevealer.Target`'s own field, no bar's (#761)"
        ),
        "KiwiCore+ShelfFrames.swift": (
            1, "`ShelfFrame`'s own field, a drawn strip's, no bar's"
        ),
        "PocketHandleView.swift": (
            1, "the pocket handle's own field, no bar's (#2678)"
        ),
        "AppBarStyle+Coding.swift": (3, "its coding key and decoder"),
        "SpaceBarStyle+Coding.swift": (3, "its coding key and decoder"),
        "SettingsRevertRegister.swift": (4, revertCopy),
    ]

    /// A row's ↺ puts the baseline's own value back into the draft,
    /// each bar's edge and per-screen map as one pair (#792).
    private static let revertCopy =
        "the revert register copies the baseline's edge pair (#792)"

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
            5,
            "the declaration, and `shelfEdges(in:on:)`, its twin "
                + "`hidingEdges(in:on:)`, `autoReadsAlways` and "
                + "`drawsAtRest` over onScreen (#761)"
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
        "SettingsRevertRegister.swift": (2, revertCopy),
        "HomeCardPlate+Bars.swift": (2, pictureDeferral),
        "HomeCardContent.swift": (
            5,
            "the Home card names the main screen's edges, read "
                + "from `homeSettings` (#1948)"
        ),
        "SettingsModel+ScreenEdges.swift": (
            1,
            "a screen row's picker shows the edge that screen gets, "
                + "`edge(on:)` (#1948)"
        ),
        "SettingsModel+BarEdges.swift": (
            1,
            "a bar row's binding shows its own edge while its "
                + "screens agree (#1948)"
        ),
        "BarsGates.swift": (
            1,
            "order and minimum grey only where no screen fuses "
                + "the bars, over `screenVariants` (#1948)"
        ),
        "ColorsAndGlassGates.swift": (
            1,
            "the front-app colour greys only where no screen "
                + "draws the name, over `screenVariants` (#1948)"
        ),
    ]

    private static let pictureDeferral =
        "the Home card pictures the main screen's edges, read "
        + "from `homeSettings` (#1948)"
    private static let keySpelling = "a census key's spelling"

    private static let guiReader = regexes([
        #"sharedBarEdge"#,
        #"\b(spaceBarStyle|appBarStyle|style)\.edge\b"#,
        // A generic read of either bar (#1948).
        #"\[keyPath:\s*\w+\]\.edge\b"#,
    ])

    /// `ScreenEdgeScope`'s memberwise init is module-wide, so its
    /// one home — `KiwiCore.screenEdgeScope(monitorSets:)`, which
    /// adds the connected screens — is held here.
    @Test("a ScreenEdgeScope is built only by screenEdgeScope")
    func scopeHasOneHome() throws {
        let found = try census(
            in: ["Sources/KiwiDeskCore", "Sources/KiwiDesk"]
        ) { _, text in
            text.components(separatedBy: "ScreenEdgeScope(").count - 1
        }
        #expect(found == ["KiwiCore+ScreenEdges.swift": 1])
    }

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
