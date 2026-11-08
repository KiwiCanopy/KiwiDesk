import Foundation
import Testing

/// The tiling toggle's wiring (#3008, state-and-layout.md): every
/// reader that decides how a window is placed takes
/// `placementMode`, the gather keeps the stored `mode` so a toggle
/// never gathers, and the stand-downs, the store's rekey and
/// forget and the mirror each sit at their one site.
@Suite("Tiling-off placement seam (#3008)")
struct TilingOffPlacementSeamTests {
    /// (function, file, directory) — each a placement decision.
    private static let placementReaders: [(String, String, String)] = [
        (
            "isEffectiveFloatOnActiveSpace",
            "KiwiCore+EffectiveFloat.swift", "Tiling"
        ),
        (
            "isEffectiveFloatForPlacement",
            "KiwiCore+FloatPlacement.swift", "App"
        ),
        ("handleDragEnd", "KiwiCore+Drag.swift", "Tiling"),
        (
            "applyWindowCreated",
            "StateCoordinator+WindowCreated.swift", "State"
        ),
    ]

    @Test("placement readers take placementMode")
    func readersTakePlacementMode() throws {
        for (function, file, directory) in Self.placementReaders {
            let body = try SourceScan.functionBody(
                of: function,
                in: file,
                under: directory
            )
            #expect(
                body.contains("placementMode(of:"),
                "\(function) reads the stored mode"
            )
        }
        for (file, count) in [
            ("TilingEngine+Layout.swift", 1),
            ("TilingEngine+Stash.swift", 1),
            ("KiwiCore+DragMove.swift", 1),
            ("KiwiCore+DragCrossing.swift", 2),
            ("KiwiCore+DragRelocate.swift", 1),
        ] {
            let url = SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent("Sources/KiwiDeskCore/Tiling")
                .appendingPathComponent(file)
            let source = try SourceScan.strippedSource(at: url)
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
                "retile", "KiwiCore+Retile.swift", "App",
                "mirrorTilingStart()"
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
