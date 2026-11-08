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
            let marker = core + "/"
            guard let cut = url.path.range(of: marker) else { continue }
            let relative = String(url.path[cut.upperBound...])
            out.append((relative, try SourceScan.strippedSource(at: url)))
        }
        return out
    }

    /// Files whose `EffectiveFloat.applies(` calls keep the stored
    /// mode, by exact count, with the reason.
    private static let storedMode: [String: (calls: Int, why: String)] = [
        "App/KiwiCore+FloatRecovery.swift": (1, parkStays)
    ]
    private static let parkStays =
        "a layout's park stays put while tiling is off; resume "
        + "places it (#3008)"

    /// A file asking `EffectiveFloat.applies(` judges a mode arm per
    /// call: it spells `placementMode(of:` at least once per call, or
    /// is ruled in `storedMode` at its exact count. Trade: a count,
    /// not a parse — a call handed a `mode` computed beside a second
    /// `placementMode` read still passes; review's. The floor keeps
    /// the census from passing on an empty walk.
    @Test("every effective-float call takes placementMode")
    func effectiveFloatCensus() throws {
        func count(_ needle: String, in text: String) -> Int {
            text.components(separatedBy: needle).count - 1
        }
        let all = try Self.coreSources().filter {
            $0.1.contains("EffectiveFloat.applies(")
        }
        #expect(all.count >= 10)
        for (file, source) in all {
            let calls = count("EffectiveFloat.applies(", in: source)
            if let ruled = Self.storedMode[file] {
                #expect(calls == ruled.calls, "\(file): \(ruled.why)")
                continue
            }
            #expect(
                count("placementMode(of:", in: source) >= calls,
                "\(file) judges a float on the stored mode"
            )
        }
        for file in Self.storedMode.keys {
            #expect(all.contains { $0.0 == file }, "\(file) moved")
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
                "Profiles", "forgetTilingToggles(of: space)"
            ),
            (
                "moveMembers", "KiwiCore+HeldSpaces.swift", "Profiles",
                "rekeyTilingToggles(source, to: target)"
            ),
            (
                "appWideLiveChanged", "KiwiCore+AppWideLive.swift", "App",
                "mirrorTilingStart()"
            ),
            (
                "handleDesktopChange", "KiwiCore+Desktops.swift",
                "Profiles",
                "desktopMemory.fileShown(snapshot)\n"
                    + "        refileTilingToggles()"
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
