import CoreGraphics
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// Settings and the tour word a connected twin by its position
/// wherever they name a screen (#3502): the Desktops card's screen
/// line, a screen setup's label, the Maximize card's screen lines
/// and the tour's screen columns, as the Screens page does. macOS
/// numbers twins in its own order, so the left one here is
/// "Twin (2)", as on the owner's desk.
@Suite("Twin screens read by position in Settings (#3502)", .serialized)
@MainActor
struct TwinScreenWordsTests {
    private let size = "100x100"

    private func model(
        _ names: [String] = ["Twin (2)", "Twin (1)"]
    ) -> SettingsModel {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-twins-\(UUID().uuidString)")
        )
        for display in core.state.workspaces.allDisplays {
            core.state.workspaces.removeDisplay(display.id)
        }
        for (index, name) in names.enumerated() {
            core.state.workspaces.upsertDisplay(
                Display(
                    id: DisplayID(UInt32(index + 1)),
                    name: name,
                    frame: CGRect(
                        x: CGFloat(index) * 100,
                        y: 0,
                        width: 100,
                        height: 100
                    )
                )
            )
        }
        let model = makeTestModel(core: core)
        // The offer's arrangement would read this Mac's own screens,
        // whose ids may be the fixture's; the names then come from
        // the connected screens alone.
        model.refreshScreenOffer([])
        return model
    }

    private static func squashed(_ file: String) throws -> String {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(file)
        return SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        ).split(whereSeparator: \.isWhitespace).joined()
    }

    @Test("a Desktop's screen line words a twin, the name stays macOS's")
    func desktopScreenLine() {
        LocalizationManager.shared.select("en")
        defer { LocalizationManager.shared.select(nil) }
        let model = model()
        #expect(model.screenWords(named: "Twin (2)") == "Twin (left)")
        #expect(model.screenWords(named: "Twin (1)") == "Twin (right)")
        // A name no connected screen carries, such as a dormant
        // record's, reads as stored.
        #expect(model.screenWords(named: "Twin") == "Twin")
        #expect(model.screenWords(named: "DELL") == "DELL")
    }

    @Test("a connected setup's twins read by position")
    func setupLabel() {
        LocalizationManager.shared.select("en")
        defer { LocalizationManager.shared.select(nil) }
        let model = model()
        #expect(
            model.setupLabel(["Twin (2):\(size)", "Twin (1):\(size)"])
                == "Twin (left) and Twin (right)"
        )
        // A disconnected screen keeps its fingerprint's name.
        #expect(model.setupLabel(["Twin:\(size)"]) == "Twin")
    }

    /// A pair macOS left unnumbered shares a name and a fingerprint,
    /// so neither lookup can tell which twin is meant: both read
    /// the shared name, never one twin's position for the other.
    @Test("an unnumbered pair reads its name, no position")
    func unnumberedPair() {
        LocalizationManager.shared.select("en")
        defer { LocalizationManager.shared.select(nil) }
        let model = model(["DELL", "DELL"])
        #expect(model.screenWords(named: "DELL") == "DELL")
        #expect(
            model.setupLabel(["DELL:\(size)", "DELL:\(size)"])
                == "DELL and DELL"
        )
    }

    @Test("the Maximize card's lines name the screen as Settings does")
    func maximizeLines() throws {
        LocalizationManager.shared.select("en")
        defer { LocalizationManager.shared.select(nil) }
        let model = model()
        let left = try #require(
            model.displays.first { $0.id == DisplayID(1) }
        )
        #expect(
            MaximizeShapeText.screenLine(
                left,
                named: model.screenLabel(left)
            ) == "Twin (left) · 100 × 100 pt"
        )
        let row = try Self.squashed(
            "Sources/KiwiDesk/Settings/Components/Layouts/"
                + "MaximizeShapeRow.swift"
        )
        #expect(
            row.contains(
                "MaximizeShapeText.screenLine($0,named:model.screenLabel($0))"
            )
        )
        #expect(row.contains("on:model.screenLabel(display),"))
        #expect(!row.contains("display.name"))
    }

    @Test("the Desktop row draws the screen through the words")
    func desktopRowWiring() throws {
        let row = try Self.squashed(
            "Sources/KiwiDesk/Settings/Components/Profiles/"
                + "DesktopsGroup+Row.swift"
        )
        #expect(row.contains("Text(model.screenWords(named:screen))"))
        #expect(!row.contains("Text(screen)"))
    }

    @Test("the tour's screen columns name a twin by position")
    func tourColumns() throws {
        let tour = try Self.squashed(
            "Sources/KiwiDesk/AppDelegate+OnboardingStart.swift"
        )
        #expect(
            tour.contains(
                "screen:SettingsModel.displaysLabel(column.display,"
                    + "among:displays)"
            )
        )
        #expect(!tour.contains("screen:column.display.name"))
    }
}
