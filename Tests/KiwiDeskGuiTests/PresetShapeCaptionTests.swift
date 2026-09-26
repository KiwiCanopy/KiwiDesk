import CoreGraphics
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The live preset group says once which shape its presets are
/// tuned for (#1663), in the Starter's own words.
@Suite("Preset shape caption (#1663)")
struct PresetShapeCaptionTests {
    private let ultrawide = CGSize(width: 3440, height: 1440)
    private let screen27 = CGSize(width: 2560, height: 1440)

    @Test("the caption names every connected screen's shape")
    @MainActor func captionNamesTheShape() {
        LocalizationManager.shared.select("en")
        #expect(
            PresetsSection.shapeCaption(sizes: [ultrawide])
                == "Tuned for: Ultrawide"
        )
        #expect(
            PresetsSection.shapeCaption(sizes: [ultrawide, screen27])
                == "Tuned for: Ultrawide and Widescreen"
        )
    }

    /// Drawn in the live group, under its heading and from the
    /// LIVE sizes — the other-setups drawer has none to name.
    @Test("the live group draws the caption once")
    func liveGroupDrawsIt() throws {
        let root = SourceScan.repoRoot(from: #filePath)
        let text = try SourceScan.strippedSource(
            at: root.appendingPathComponent(
                "Sources/KiwiDesk/Settings/Sections/"
                    + "PresetsSection.swift"
            )
        ).filter { !$0.isWhitespace }
        let needle =
            "SettingsGroupHeader(liveHeading).padding(.top,4)"
            + "Text(Self.shapeCaption(sizes:liveSizes))"
        #expect(text.components(separatedBy: needle).count == 2)
        #expect(
            text.components(separatedBy: "Self.shapeCaption(").count
                == 2
        )
    }
}
