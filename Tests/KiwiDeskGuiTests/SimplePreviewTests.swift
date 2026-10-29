import Foundation
import SwiftUI
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// Simple's live preview (#2737 rulings 5, 9 and 10): which Space it
/// shows, in which look, how wide it docks, and that the kept row's
/// ring reads against its fill. Main-actor spend: model construction
/// and four colour resolutions.
@MainActor
@Suite("Simple preview")
struct SimplePreviewTests {
    private func model(_ spaces: [String]) -> SettingsModel {
        let defaults = makeScratchDefaults().defaults
        SettingsRootPreference.write(.simple, to: defaults)
        let model = makeTestModel(defaults: defaults)
        model.config.spaces = spaces.map { SpaceID($0) }
        return model
    }

    @Test("a hover outranks the kept Space, the kept the first")
    func shownSpace() {
        let model = model(["a", "b", "c"])
        #expect(model.simplePreviewSpace?.raw == "a")
        #expect(model.simplePreviewIsKept)
        model.nav.simpleKept = SpaceID("b")
        #expect(model.simplePreviewSpace?.raw == "b")
        model.hoverSimple(.space(SpaceID("c")), inside: true)
        #expect(model.simplePreviewSpace?.raw == "c")
        #expect(!model.simplePreviewIsKept)
        #expect(model.simpleKeptSpace?.raw == "b")
        // A kept Space deleted falls back to the first.
        model.hoverSimple(.space(SpaceID("c")), inside: false)
        model.config.spaces.removeAll { $0.raw == "b" }
        #expect(model.simplePreviewSpace?.raw == "a")
    }

    /// The next row's enter can land before this row's leave.
    @Test("a leave clears only its own hover")
    func leaveKeepsTheNext() {
        let model = model(["a", "b"])
        model.hoverSimple(.space(SpaceID("b")), inside: true)
        model.hoverSimple(.space(SpaceID("a")), inside: false)
        #expect(model.nav.simpleHover == .space(SpaceID("b")))
        model.hoverSimple(.space(SpaceID("b")), inside: false)
        #expect(model.nav.simpleHover == nil)
    }

    @Test("a hovered look is painted over the draft, not written")
    func lookHoverPaints() throws {
        let model = model(["a"])
        let look = try #require(
            model.core.bundledLooks.first {
                $0.match(model.config.settings) == .none
            }
        )
        let before = model.config.settings
        model.hoverSimple(.look(look.name), inside: true)
        #expect(model.simplePreviewSettings != before)
        #expect(model.config.settings == before)
        #expect(!model.simplePreviewIsKept)
        model.hoverSimple(.look("No such look"), inside: true)
        #expect(model.simplePreviewSettings == before)
        #expect(model.simplePreviewHover == nil)
        #expect(model.simplePreviewIsKept)
    }

    @Test("a new visit forgets the kept and hovered Space")
    func visitResets() {
        let model = model(["a", "b"])
        model.nav.simpleKept = SpaceID("b")
        model.nav.simpleHover = .space(SpaceID("a"))
        model.nav.resetSurfaces()
        #expect(model.nav.simpleKept == nil)
        #expect(model.nav.simpleHover == nil)
    }

    /// A fallback that is not the main screen is named as itself.
    @Test("an offline pin names a fallback that is not main as such")
    func fallbackSentence() {
        LocalizationManager.shared.select("en")
        let side = Display(
            id: DisplayID(2),
            name: "Side",
            frame: CGRect(x: 100, y: 0, width: 100, height: 100)
        )
        let elsewhere = SettingsModel.offlinePinSentence(
            waiting: "Dell",
            fallback: side,
            fallbackIsMain: false
        )
        #expect(elsewhere.contains("Side"))
        #expect(!elsewhere.contains("main screen"))
        let main = SettingsModel.offlinePinSentence(
            waiting: "Dell",
            fallback: side,
            fallbackIsMain: true
        )
        #expect(main.contains("the main screen"))
    }

    /// Ruling 10's floor: the docking width leaves the controls 580.
    @Test("the docked preview leaves the controls their 580")
    func controlsKeepTheirFloor() {
        let controls =
            SettingsWidthClass.panelBreakpoint
            - SimpleColumns.preview - 1
        #expect(controls >= 580)
        #expect(SimpleColumns.contentCap >= controls)
    }

    @Test("an offline pin's caption keeps the hover and both screens")
    func offlineCaption() {
        LocalizationManager.shared.select("en")
        let model = model(["a"])
        let core = model.core
        for display in core.state.workspaces.allDisplays {
            core.state.workspaces.removeDisplay(display.id)
        }
        core.state.workspaces.upsertDisplay(
            Display(
                id: DisplayID(1),
                name: "Built-in",
                frame: CGRect(x: 0, y: 0, width: 100, height: 100)
            )
        )
        let space = SpaceID("a")
        model.config.spacePins[space] = "Dell:200x100"
        let preview = SimplePreview(model: model)
        let sentence = model.offlinePinSentence(space)
        // Names the screen it waits for and the one the map lights.
        #expect(sentence.contains("Dell"))
        #expect(sentence.contains("Built-in"))
        // Its one screen is the main one, and the sentence says so.
        #expect(sentence.contains("the main screen"))
        #expect(model.simpleLanding(of: space)?.name == "Built-in")
        #expect(preview.caption(space) == sentence)
        model.hoverSimple(.space(space), inside: true)
        let hovered = preview.caption(space) ?? ""
        #expect(hovered.contains("Previewing a"))
        #expect(hovered.contains(sentence))
        model.config.spacePins[space] = nil
        model.hoverSimple(.space(space), inside: false)
        #expect(preview.caption(space) == nil)
    }

    /// A row that compared `nav.simpleKept` itself would ring a
    /// deleted Space's neighbour wrong; the one reading is held.
    @Test("rows mark kept through the one reading")
    func rowsReadTheKeptSpace() throws {
        let file = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Simple/"
                    + "SimpleSpacesCard.swift"
            )
        let text = try SourceScan.strippedSource(at: file)
            .filter { !$0.isWhitespace }
        #expect(text.contains("model.simpleKeptSpace==space"))
        // The ring and the fill are drawn from that reading, in the
        // measured pair.
        #expect(text.contains("isKept(space)?Self.keptRing:.clear"))
        #expect(text.contains("ifisKept(space){shape.fill(Self.keptFill)"))
        // The row only writes the kept Space — the tap and the menu
        // item — and never reads it.
        #expect(text.occurrences(of: "nav.simpleKept") == 2)
        #expect(text.occurrences(of: "nav.simpleKept=space") == 2)
    }

    /// The ring is the kept cue, so it must part from the fill it
    /// rims for a protanope too (#2737 ruling 5).
    @Test("the kept ring separates from the kept fill")
    func ringSeparates() throws {
        for dark in [false, true] {
            let card = try ThemeContrast.resolved(
                SettingsTheme.card,
                dark: dark
            )
            let ground = try over(SimpleSpacesCard.keptFill, card, dark)
            // The ring draws at its own alpha over that same ground.
            let ring = try over(SimpleSpacesCard.keptRing, ground, dark)
            let separation = try #require(
                ColorVision.separation(hex(ring), hex(ground))
            )
            #expect(
                separation >= ColorVision.separationFloor,
                "\(dark ? "dark" : "light"): \(separation)"
            )
        }
    }

    /// `color` composited at its resolved alpha over `ground`.
    private func over(
        _ color: Color,
        _ ground: (r: Double, g: Double, b: Double),
        _ dark: Bool
    ) throws -> (r: Double, g: Double, b: Double) {
        let top = try ThemeContrast.resolved(color, dark: dark)
        let a = try ThemeContrast.resolvedAlpha(color, dark: dark)
        return (
            top.r * a + ground.r * (1 - a),
            top.g * a + ground.g * (1 - a),
            top.b * a + ground.b * (1 - a)
        )
    }

    private func hex(_ rgb: (r: Double, g: Double, b: Double)) -> String {
        "#"
            + [rgb.r, rgb.g, rgb.b]
            .map { String(format: "%02X", Int(($0 * 255).rounded())) }
            .joined()
    }
}
