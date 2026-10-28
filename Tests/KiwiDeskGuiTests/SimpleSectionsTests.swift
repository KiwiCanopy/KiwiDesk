import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// Simple's sections (#2737): the Screen menu's one placement door,
/// the save pill's jump, and Simple drawing Advanced's own parts.
/// Main-actor spend: model construction and one source walk of a
/// single directory.
@MainActor
@Suite("Simple sections")
struct SimpleSectionsTests {
    private func onSimple() -> SettingsModel {
        let defaults = makeScratchDefaults().defaults
        SettingsRootPreference.write(.simple, to: defaults)
        return makeTestModel(defaults: defaults)
    }

    @Test("each placement clears the other one")
    func placementRoundTrips() {
        let model = onSimple()
        let space = SpaceID("1")
        model.place(space, .screen("fp-a"))
        #expect(model.config.spacePins[space] == "fp-a")
        #expect(model.screenChoice(of: space) == .screen("fp-a"))
        model.place(space, .followsMain)
        #expect(model.config.spacePins[space] == nil)
        #expect(model.config.mainSpaces.contains(space))
        #expect(model.screenChoice(of: space) == .followsMain)
        model.place(space, .screen("fp-b"))
        #expect(!model.config.mainSpaces.contains(space))
        model.place(space, .auto)
        #expect(model.config.spacePins[space] == nil)
        #expect(!model.config.mainSpaces.contains(space))
        #expect(model.screenChoice(of: space) == .auto)
    }

    private func row(_ key: SettingKey) -> SettingsDiffRow {
        SettingsDiffRow(id: "row", key: key, label: "Row")
    }

    /// Ruling 12: a row Simple draws stays; any other leaves.
    @Test("a pill row leaves Simple only for a control it lacks")
    func pillRowJump() {
        let model = onSimple()
        model.jump(to: row(.spaces(.spaceModes)))
        #expect(model.nav.pendingReveal == nil)
        model.jump(to: row(.gaps(.outerTop)))
        #expect(model.nav.pendingReveal != nil)
        // On Advanced every row lands on its page.
        model.nav.pendingReveal = nil
        model.pickRoot(.advanced)
        model.jump(to: row(.spaces(.spaceModes)))
        #expect(model.nav.pendingReveal?.destination == .spaces)
    }

    @Test("Simple's hints place their links")
    func hintsPlaceTheirLinks() {
        LocalizationManager.shared.select("en")
        for prose in [SimpleLookCard.hintProse, SimpleSpacesCard.hintProse] {
            #expect(prose.contains(CrossReferenceRow.linkSlot))
        }
    }

    @Test("Simple's coverage names only what it draws")
    func coverage() {
        #expect(SimpleCoverage.draws(.spaces(.spaceModes)))
        #expect(SimpleCoverage.draws(.screens(.spacePins)))
        #expect(SimpleCoverage.draws(.shortcuts(.openApplications)))
        #expect(!SimpleCoverage.draws(.spaces(.fallbackSpace)))
        #expect(!SimpleCoverage.draws(.shortcuts(.layers)))
        #expect(!SimpleCoverage.draws(.gaps(.outerTop)))
    }

    /// Simple owns layout only: a tile, a recorder or a layout
    /// menu is drawn by the component Advanced draws it with, so
    /// none is built from parts under Simple's directory.
    @Test("Simple builds no control of its own")
    func noLookAlikes() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Simple"
            )
        let files = try SourceScan.swiftSources(under: root)
        #expect(!files.isEmpty)
        let parts = [
            "PaletteTile(", "LookPlate(", "KeyRecorderField(",
            "LayoutMode.allCases", "OverrideCountBadge(",
            "SpacePinBadge.resolve(",
        ]
        for file in files {
            let text = try SourceScan.strippedSource(at: file)
            for part in parts {
                #expect(
                    !text.contains(part),
                    "\(file.lastPathComponent) builds \(part)"
                )
            }
        }
    }
}
