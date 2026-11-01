import Foundation
import Testing

@testable import KiwiDesk

/// Every desk picture draws the plate its look earned (#2859):
/// each in-scope surface reads the resolved paint through
/// `deskPlate`/`platePaint` or the palette they write, a plate
/// view with no writer takes `SchematicPalette.unresolved`, and
/// two sets close it: only the resolver names the dark plate
/// token, and only the resolver, `LookPlate` (#1740) and KiwiHub's
/// `JumpLayoutTile` write the palette environment.
@Suite("Plate ground wiring")
struct PlateGroundWiringTests {
    /// Surface file → the squashed consult it must carry.
    private let surfaces: [String: String] = [
        "HomeCardPlate.swift": ".deskPlate(settings,in:Rectangle())",
        "SimpleSpacePicture.swift": ".deskPlate(settings,in:shape)",
        "BarsPanelPreview.swift":
            ".deskPlate(settings,in:RoundedRectangle(cornerRadius:12))",
        "PaletteScenePanel.swift":
            ".deskPlate(settings,in:RoundedRectangle(cornerRadius:12))",
        "KeyboardPreviewPanel.swift": ".platePaint(model.config.settings)",
        "KeyboardBoard.swift": ".fill((palette??.unresolved).base)",
        "GesturesDrawer.swift": ".platePaint(settings)",
        "GestureEntry.swift": ".background((palette??.unresolved).base)",
        "KiwiVisionPanelPreview.swift":
            ".platePaint(model.config.settings)",
        "KiwiVisionScene.swift": "resolved??.unresolved",
        "OnboardingSpaceRow.swift": ".deskPlate(settings,",
        "OnboardingView+Closing.swift": ".deskPlate(model.tilingSettings(),",
        "LayoutStrip.swift": ".deskPlate(model.config.settings,",
        "LayoutPreviewPanel.swift": ".deskPlate(model.config.settings,",
        "SpacesPanelPreview.swift": ".deskPlate(settings,",
    ]

    /// The one file that names the dark plate token.
    private let resolver = "HomeCardPlate+Ground.swift"

    private func sources() throws -> [(String, String)] {
        try ChromeScanRoots.sources(from: #filePath).map {
            (
                $0.lastPathComponent,
                SourceScan.stripComments(
                    try String(contentsOf: $0, encoding: .utf8)
                )
                .split(whereSeparator: \.isWhitespace).joined()
            )
        }
    }

    @Test("every surface reads the resolved paint")
    func surfacesReadThePaint() throws {
        let all = Dictionary(
            try sources(),
            uniquingKeysWith: { first, _ in first }
        )
        for (file, needle) in surfaces {
            let source = try #require(
                all[file],
                Comment(rawValue: "\(file) not found")
            )
            #expect(
                source.contains(needle),
                Comment(rawValue: "\(file) lost its plate paint")
            )
            #expect(
                !source.contains("SettingsTheme.previewPlate"),
                Comment(rawValue: "\(file) names the dark plate")
            )
            // The verdict reads the window's appearance; a picture
            // forcing its own would pick the plate for it. The
            // KiwiVision scene's windows take the appearance the
            // mode will show, below the writer, and are the one
            // spelling allowed.
            let forced = source.replacingOccurrences(
                of: ".environment(\\.colorScheme,darkWindows?.dark:.light)",
                with: ""
            )
            #expect(
                !forced.contains("\\.colorScheme")
                    && !forced.contains("preferredColorScheme("),
                Comment(rawValue: "\(file) forces an appearance")
            )
        }
        // One fallback: a plate view with no writer reads the
        // resolver's unresolved paint, never a plate it picks. The
        // schematic kit's own `card` fallbacks are its brand mode,
        // drawn with no plate at all.
        for (file, source) in all
        where !file.hasPrefix("LayoutSchematic")
            && source.contains("palette?.base??")
        {
            Issue.record(
                Comment(rawValue: "\(file) picks its own plate")
            )
        }
    }

    @Test("only the resolver names the dark plate or writes paint")
    func oneResolver() throws {
        let writers: Set<String> = [
            resolver, "LookPlate.swift", "JumpLayoutTile.swift",
        ]
        var named: Set<String> = []
        var wrote: Set<String> = []
        for (file, source) in try sources() {
            if source.contains("SettingsTheme.previewPlate") {
                named.insert(file)
            }
            // Any mention that is not an `@Environment` read is a
            // write, whatever the modifier spelling it.
            let mentions = source.occurrences(of: "\\.schematicPalette")
            let reads = source.occurrences(
                of: "@Environment(\\.schematicPalette)"
            )
            if mentions > reads { wrote.insert(file) }
        }
        #expect(named == [resolver])
        #expect(wrote == writers)
    }
}
