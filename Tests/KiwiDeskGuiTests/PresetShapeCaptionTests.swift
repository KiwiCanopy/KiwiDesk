import CoreGraphics
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// A preset card for the connected screens says which shape the
/// preset is tuned for (#1663); the Starter, named by its shape,
/// and a card for other setups say nothing.
@Suite("Preset shape caption (#1663)")
struct PresetShapeCaptionTests {
    private let ultrawide = CGSize(width: 3440, height: 1440)
    private let screen27 = CGSize(width: 2560, height: 1440)

    private func developer() throws -> StandardLayout {
        try #require(
            StandardProfiles.workflows.first { $0.name == "Developer" }
        )
    }

    @Test("a live preset names its screen's shape")
    @MainActor func livePresetIsCaptioned() throws {
        LocalizationManager.shared.select("en")
        let caption = PresetCard.shapeCaption(
            try developer(),
            sizes: [ultrawide]
        )
        #expect(caption == "Tuned for Ultrawide")
        #expect(
            PresetCard.shapeCaption(
                try developer(),
                sizes: [ultrawide, screen27]
            ) == "Tuned for Ultrawide + 1"
        )
    }

    @Test("other setups and the Starter carry no caption")
    @MainActor func noCaption() throws {
        LocalizationManager.shared.select("en")
        #expect(PresetCard.shapeCaption(try developer(), sizes: nil) == nil)
        let starter = StarterSetup.standardLayout(sizes: [ultrawide])
        #expect(
            PresetCard.shapeCaption(starter, sizes: [ultrawide]) == nil
        )
    }

    @Test("the card draws the caption")
    func cardDrawsIt() throws {
        let root = SourceScan.repoRoot(from: #filePath)
        let file = root.appendingPathComponent(
            "Sources/KiwiDesk/Settings/Components/Profiles/"
                + "PresetCard.swift"
        )
        let body = try SourceScan.strippedSource(at: file)
            .filter { !$0.isWhitespace }
        #expect(
            body.contains(
                "ifletcaption=Self.shapeCaption(layout,sizes:sizes){"
                    + "Text(caption)"
            )
        )
    }
}
