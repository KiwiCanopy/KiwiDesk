import CoreGraphics
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The Screens editor's draft writes (#3517 rulings 22–24): split,
/// merge with its pin rewrite, the floor from Core, renames through
/// Core's rule, area pins resolving to their pane, and a readout
/// that tells ids apart.
@MainActor
@Suite("Screen area edits")
struct ScreenAreaEditTests {
    private func model() -> (SettingsModel, Display) {
        let model = makeTestModel()
        let screen = Display(
            id: DisplayID(77),
            name: "Wide",
            frame: CGRect(x: 0, y: 0, width: 3440, height: 1440)
        )
        model.core.state.workspaces.upsertDisplay(screen)
        model.config.settings.minWindowSizes =
            MinWindowSizes(all: .square(300))
        return (model, screen)
    }

    @Test func splitKeepsTheLeadingId() throws {
        let (model, screen) = model()
        #expect(model.areaSplit(of: screen) == nil)
        model.splitArea(0, on: screen, .sideBySide)
        let split = try #require(model.areaSplit(of: screen))
        #expect(split.areas.map(\.id) == [0, 1])
        #expect(ScreenAreaEditing.axes(of: model, screen) == [.sideBySide])
    }

    @Test func splitGreysAtCoresFloor() {
        let (model, screen) = model()
        model.config.settings.minWindowSizes =
            MinWindowSizes(all: .square(2000))
        #expect(!model.canSplit(0, on: screen, .sideBySide))
        model.splitArea(0, on: screen, .sideBySide)
        #expect(model.areaSplit(of: screen) == nil)
    }

    @Test func mergeRewritesPinsAndLeavesAreaZero() throws {
        let (model, screen) = model()
        model.splitArea(0, on: screen, .sideBySide)
        let space = SpaceID("4")
        model.config.spaces.append(space)
        let right = ScreenAreaKey(
            fingerprint: screen.fingerprint,
            areaID: 1
        ).description
        model.place(space, .screen(right))
        #expect(model.mergeNeighbours(of: 1, on: screen) == [0])
        let kept = model.mergeArea(1, with: 0, on: screen)
        #expect(kept == 0)
        #expect(model.config.spacePins[space] == screen.fingerprint)
        #expect(model.areaSplit(of: screen) == nil)
    }

    @Test func areaPinLandsInItsPane() throws {
        let (model, screen) = model()
        model.splitArea(0, on: screen, .sideBySide)
        let space = SpaceID("4")
        model.config.spaces.append(space)
        let right = ScreenAreaKey(
            fingerprint: screen.fingerprint,
            areaID: 1
        ).description
        model.place(space, .screen(right))
        let rows = model.screenRows
        #expect(rows.chips(on: right).map(\.space) == [space])
        #expect(
            !rows.chips(on: screen.fingerprint).contains {
                $0.space == space
            }
        )
        #expect(rows.orphans.isEmpty)
        // A key whose area is gone falls back to area 0 (ruling 22).
        model.place(space, .screen(screen.fingerprint + "#9"))
        #expect(
            model.screenRows.chips(on: screen.fingerprint).contains {
                $0.space == space
            }
        )
    }

    @Test func renameGoesThroughCoresRule() throws {
        LocalizationManager.shared.select("en")
        let (model, screen) = model()
        model.splitArea(0, on: screen, .sideBySide)
        #expect(model.areaLabel(1, on: screen) == "Right")
        #expect(model.areaNameProblem("42", for: 1, on: screen) == .number)
        #expect(model.areaNameProblem("Wide", for: 1, on: screen) == .taken)
        model.renameArea(1, on: screen, to: "Call")
        #expect(model.areaLabel(1, on: screen) == "Call")
        #expect(model.areaName(1, on: screen).hasSuffix(" – Call"))
        model.renameArea(1, on: screen, to: "")
        #expect(model.areaLabel(1, on: screen) == "Right")
    }

    /// A re-split that changes only ids, or a rename, must not book
    /// a row whose two sides read alike.
    @Test func readoutShowsIdsAndNames() throws {
        let whole = ScreenSplit.whole(width: 3440, height: 1440)
        let one = try #require(whole.splitting(0, .sideBySide))
        var other = one
        other.areas[1].id = 5
        var named = one
        named.areas[1].name = "Call"
        let base = GuiConfig()
        for changed in [other, named] {
            var old = base
            old.settings.displayAreas["W:3440x1440"] = one
            var new = base
            new.settings.displayAreas["W:3440x1440"] = changed
            let rows = SettingsValueReadout.screensRows(
                .displayAreas,
                old: old,
                new: new
            )
            #expect(rows.count == 1)
            let text = String(describing: rows)
            #expect(text.contains("#1"))
            #expect(text.contains(changed == other ? "#5" : "“Call”"))
        }
    }
}
