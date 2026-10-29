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

    /// Docks only where a page's panel docks, and leaves the
    /// controls at least their ruled 580 pt at the docking width.
    @Test("the preview docks where a panel docks, leaving 580")
    func columns() {
        for width in SettingsWidthClass.allCases {
            #expect(
                (SimpleColumns.dockedPreview(width) != nil)
                    == width.docksPanel
            )
        }
        #expect(SimpleColumns.minimumControls >= 580)
        #expect(SimpleColumns.contentCap >= SimpleColumns.minimumControls)
    }

    @Test("an offline pin's preview names both screens")
    func offlineCaption() {
        LocalizationManager.shared.select("en")
        let model = model(["a"])
        model.config.spacePins[SpaceID("a")] = "absent-screen"
        let preview = SimplePreview(model: model)
        #expect(model.spacePinBadge(SpaceID("a")) == .offline)
        #expect(
            preview.caption(SpaceID("a"))
                == model.offlinePinSentence(SpaceID("a"))
        )
        model.config.spacePins[SpaceID("a")] = nil
        #expect(preview.caption(SpaceID("a")) == nil)
    }

    /// The ring is the kept cue, so it must part from the fill it
    /// rims for a protanope too (#2737 ruling 5).
    @Test("the kept ring separates from the kept fill")
    func ringSeparates() throws {
        for dark in [false, true] {
            let ring = try hex(
                ThemeContrast.resolved(
                    SettingsTheme.accent,
                    dark: dark
                )
            )
            let card = try ThemeContrast.resolved(
                SettingsTheme.card,
                dark: dark
            )
            let fill = try ThemeContrast.resolved(
                SettingsTheme.chipHover,
                dark: dark
            )
            let alpha = try ThemeContrast.resolvedAlpha(
                SettingsTheme.chipHover,
                dark: dark
            )
            let ground = hex(
                (
                    fill.r * alpha + card.r * (1 - alpha),
                    fill.g * alpha + card.g * (1 - alpha),
                    fill.b * alpha + card.b * (1 - alpha)
                )
            )
            let separation = try #require(
                ColorVision.separation(ring, ground)
            )
            #expect(
                separation >= ColorVision.separationFloor,
                "\(dark ? "dark" : "light"): \(separation)"
            )
        }
    }

    private func hex(_ rgb: (r: Double, g: Double, b: Double)) -> String {
        "#"
            + [rgb.r, rgb.g, rgb.b]
            .map { String(format: "%02X", Int(($0 * 255).rounded())) }
            .joined()
    }
}
