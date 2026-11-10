import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// KiwiVision ▸ Maximize's summary line (#3161): Height and Width
/// name the share and anchor Layout Defaults ▸ Maximize holds for
/// each connected screen shape; Off and Full name nothing.
/// Main-actor spend: string building and one source scan.
@Suite("KiwiVision Maximize summary (#3161)")
@MainActor
struct KiwiVisionMaximizeSummaryTests {
    private typealias Summary = KiwiVisionMaximizeSummary
    private let slot = CrossReferenceRow.linkSlot

    private func settings() -> MaximizeSettings {
        var maximize = MaximizeSettings()
        maximize.heightShare[.laptop] = 0.75
        maximize.heightShare[.widescreen] = 1.0 / 3
        maximize.widthShare[.laptop] = 0.5
        maximize.anchor[.laptop] = .center
        maximize.anchor[.widescreen] = .center
        return maximize
    }

    @Test("one shape names its share, anchor and shape")
    func oneShape() throws {
        LocalizationManager.shared.select("en")
        let height = try #require(
            Summary.prose(
                fill: .height,
                maximize: settings(),
                shapes: [.laptop]
            )
        )
        #expect(
            height == "¾ wide · from Center, on Laptop. Change in \(slot)."
        )
        let width = try #require(
            Summary.prose(
                fill: .width,
                maximize: settings(),
                shapes: [.laptop]
            )
        )
        #expect(width.hasPrefix("½ tall · from Center, on Laptop."))
    }

    @Test("two shapes list both; differing anchors go per entry")
    func twoShapes() throws {
        LocalizationManager.shared.select("en")
        var maximize = settings()
        let shared = try #require(
            Summary.prose(
                fill: .height,
                maximize: maximize,
                shapes: [.laptop, .widescreen]
            )
        )
        #expect(
            shared
                == "Width: Laptop ¾ · Widescreen ⅓ · from Center. "
                + "Change in \(slot)."
        )
        maximize.anchor[.widescreen] = .inPlace
        let mixed = try #require(
            Summary.prose(
                fill: .height,
                maximize: maximize,
                shapes: [.laptop, .widescreen]
            )
        )
        #expect(
            mixed
                == "Width: Laptop ¾ from Center · Widescreen ⅓ from "
                + "Where it is. Change in \(slot)."
        )
    }

    /// The line names the screen shape's value whatever a Space
    /// overrides (#3090), and nothing for Off, Full or no screen.
    @Test("Off, Full and no screen name nothing; overrides are unread")
    func silences() throws {
        LocalizationManager.shared.select("en")
        var maximize = settings()
        for fill in [VisionMaximize.off, .full] {
            #expect(
                Summary.prose(
                    fill: fill,
                    maximize: maximize,
                    shapes: [.laptop]
                ) == nil
            )
        }
        #expect(
            Summary.prose(fill: .height, maximize: maximize, shapes: [])
                == nil
        )
        let before = Summary.prose(
            fill: .height,
            maximize: maximize,
            shapes: [.laptop]
        )
        maximize.shareOverride[SpaceID("1")] = MaximizeShareOverride(
            height: 0.25
        )
        #expect(
            Summary.prose(
                fill: .height,
                maximize: maximize,
                shapes: [.laptop]
            ) == before
        )
    }

    /// Both pages draw the one view, each handing the fill it
    /// shows; a lens's row only while checked (amendment).
    @Test("Default and a checked lens row draw the line, linked")
    func wiring() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/KiwiVision"
            )
        let read = { (name: String) in
            try SourceScan.strippedSource(
                at: root.appendingPathComponent(name)
            ).split(whereSeparator: \.isWhitespace).joined()
        }
        let card = try read("KiwiVisionMaximizeCard.swift")
        #expect(
            card.contains(
                "disabled:reason(for:key)!=nil)"
                    + "KiwiVisionMaximizeSummary(model:model,"
                    + "fill:model.appWide.visionMaximize)"
            )
        )
        let lens = try read("KiwiVisionLensOverrides.swift")
        #expect(
            lens.contains(
                "maximizeRowifletfill=lens.overrides.maximize{"
                    + "KiwiVisionMaximizeSummary(model:model,fill:fill)}"
            )
        )
        let line = try read("KiwiVisionMaximizeSummary.swift")
        #expect(line.contains("fill:fill,maximize:model.config.settings"))
        #expect(
            line.contains("shapes:MaximizeCard.shownShapes(of:model.displays)")
        )
        #expect(line.contains("destination:.layoutDefaults"))
    }

    /// The line is the link, so the `?` names no page (amendment).
    @Test("the help names no page in plain words")
    func helpNamesNoPage() {
        LocalizationManager.shared.select("en")
        let help = KiwiVisionMaximizeRow.help
        #expect(!help.contains(SettingsDestination.layoutDefaults.title))
        #expect(help.contains("full height or width"))
    }
}
