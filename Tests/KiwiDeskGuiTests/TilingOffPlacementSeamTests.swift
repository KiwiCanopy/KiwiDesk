import Foundation
import Testing

/// The tiling toggle's wiring (#3008, state-and-layout.md): every
/// reader that decides how a window is placed takes
/// `placementMode`, the gather keeps the stored `mode` so a toggle
/// never gathers, and the stand-downs, the store's rekey and
/// forget and the mirror each sit at their one site.
@Suite("Tiling-off placement seam (#3008)")
struct TilingOffPlacementSeamTests {
    private static let core = "Sources/KiwiDeskCore"

    /// Every Core file under `Sources/KiwiDeskCore`, stripped.
    private static func coreSources() throws -> [(String, String)] {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(core)
        let walker = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: nil
        )
        var out: [(String, String)] = []
        while let url = walker?.nextObject() as? URL {
            guard url.pathExtension == "swift" else { continue }
            let relative = String(
                url.path.dropFirst(root.path.count + 1)
            )
            out.append((relative, try SourceScan.strippedSource(at: url)))
        }
        return out
    }

    /// Files whose `EffectiveFloat.applies(` keeps the stored mode,
    /// each with its reason.
    private static let storedMode: [String: String] = [
        "Tiling/EffectiveFloat.swift": "the predicate itself",
        "App/KiwiCore+FloatRecovery.swift":
            "a layout's park stays put while tiling is off; resume "
            + "places it (#3008)",
    ]

    /// A file asking `EffectiveFloat.applies(` judges a mode arm:
    /// it takes the placement mode, or is ruled in `storedMode`.
    /// The floor keeps the census from passing on an empty walk.
    @Test("every effective-float file takes placementMode")
    func effectiveFloatCensus() throws {
        let all = try Self.coreSources().filter {
            $0.1.contains("EffectiveFloat.applies(")
        }
        for file in Self.storedMode.keys {
            #expect(all.contains { $0.0 == file }, "\(file) moved")
        }
        let callers = all.filter { Self.storedMode[$0.0] == nil }
        #expect(callers.count >= 10)
        for (file, source) in callers {
            #expect(
                source.contains("placementMode(of:"),
                "\(file) judges a float on the stored mode"
            )
        }
    }

    /// The placement gates outside `EffectiveFloat`, by count.
    @Test("the placement gates take placementMode")
    func gatesTakePlacementMode() throws {
        let gates: [String: Int] = [
            "Tiling/TilingEngine+Layout.swift": 1,
            "Tiling/KiwiCore+Drag.swift": 1,
            "Tiling/KiwiCore+DragMove.swift": 1,
            "Tiling/KiwiCore+DragCrossing.swift": 2,
            "Tiling/KiwiCore+DragRelocate.swift": 1,
            "App/KiwiCore+Maximize.swift": 1,
            "App/KiwiCore+AppBarVisibility.swift": 1,
            "State/StateCoordinator+Maximized.swift": 1,
        ]
        let sources = Dictionary(
            try Self.coreSources(),
            uniquingKeysWith: { first, _ in first }
        )
        for (file, count) in gates {
            let source = try #require(sources[file], "\(file) missing")
            #expect(
                source.components(separatedBy: "placementMode(of:")
                    .count - 1 == count,
                "\(file) routes \(count) gate(s)"
            )
        }
    }

    @Test("the Floating gather keeps the stored mode")
    func gatherKeepsTheMode() throws {
        let body = try SourceScan.functionBody(
            of: "gatherIntoFloating",
            in: "KiwiCore+FloatGather.swift",
            under: "App"
        )
        #expect(!body.contains("placementMode"))
        #expect(body.contains("space.mode == .floating"))
    }

    /// The shelf's tiling-off read has its one other reader, the
    /// menu-bar mark (bars.md); the mirror has one writer.
    @Test("the shelf read and the mirror keep their sites")
    func singleSites() throws {
        let sources = try Self.coreSources()
        func callers(_ needle: String) -> [String] {
            sources.filter { $0.1.contains(needle) }.map(\.0).sorted()
        }
        #expect(
            callers("tilingOffHidesShelf(on:")
                == [
                    "App/KiwiCore+ScreenCovering.swift",
                    "App/KiwiCore+StatusSpaceMark.swift",
                    "App/KiwiCore+TilingToggle.swift",
                ]
        )
        #expect(
            callers("state.tilingStart = ")
                == ["App/KiwiCore+TilingToggle.swift"]
        )
    }

    @Test("stand-downs, store hooks and the mirror sit at their sites")
    func sitesAreWired() throws {
        let sites: [(String, String, String, String)] = [
            (
                "shelfStandsDown", "KiwiCore+ScreenCovering.swift", "App",
                "tilingOffHidesShelf(on: display)"
            ),
            (
                "desiredBorderSpecs", "KiwiCore+Borders.swift", "App",
                "tilingOffHidesRings(on: space.id)"
            ),
            (
                "forwardWindows", "KiwiCore+ProfileSpaces.swift",
                "Profiles", "state.forgetTilingToggle(of: space)"
            ),
            (
                "moveMembers", "KiwiCore+HeldSpaces.swift", "Profiles",
                "state.rekeyTilingToggle(source, to: target)"
            ),
            (
                "appWideLiveChanged", "KiwiCore+AppWideLive.swift", "App",
                "mirrorTilingStart()"
            ),
            (
                "bootstrapCoreServices", "KiwiCore+Bootstrap.swift", "App",
                "self?.mirrorTilingStart()"
            ),
        ]
        for (function, file, directory, needle) in sites {
            let body = try SourceScan.functionBody(
                of: function,
                labeled: function == "shelfStandsDown"
                    ? "on display: DisplayID, covered" : "",
                in: file,
                under: directory
            )
            #expect(body.contains(needle), "\(function) lost \(needle)")
        }
    }
}
