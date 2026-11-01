import Foundation
import Testing

@testable import KiwiDesk

/// Every desk picture draws the plate its look earned (#2859):
/// each in-scope surface reads the resolved paint through
/// `deskPlate`/`platePaint` or the palette they write, and none
/// names the dark plate token itself — a direct read draws the
/// dark plate in light mode with every other suite green.
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
        "KeyboardBoard.swift": ".fill(palette?.base??SettingsTheme.card)",
        "GesturesDrawer.swift": ".platePaint(settings)",
        "GestureEntry.swift": ".background(palette?.base??SettingsTheme.card)",
        "OnboardingSpaceRow.swift": ".deskPlate(settings,",
        "OnboardingView+Closing.swift": ".deskPlate(model.tilingSettings(),",
        "LayoutStrip.swift": ".deskPlate(model.config.settings,",
        "LayoutPreviewPanel.swift": ".deskPlate(model.config.settings,",
        "SpacesPanelPreview.swift": ".deskPlate(settings,",
    ]

    /// The files that may name the dark plate token or write the
    /// palette environment: the resolver, and the two pictures
    /// ruled onto their own ground (`LookPlate` #1740, KiwiHub).
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
            if source.contains("\\.schematicPalette,") {
                wrote.insert(file)
            }
        }
        #expect(named == [resolver])
        #expect(wrote == writers)
    }
}
