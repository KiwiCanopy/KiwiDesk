import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The GUI half of the bars' right-click menus (#1518): where a
/// Settings row lands, and how an open draft takes a setting a
/// menu wrote into the live profile, so its next Save does not
/// write the old value back.
@Suite("Bar menu landing and live write", .serialized)
@MainActor
struct BarMenuLandingTests {
    @Test("each landing names its page, and the shelf its card")
    func landings() {
        #expect(
            SettingsAnchor(landing: .shelf)
                == SettingsAnchor(
                    destination: .bars,
                    anchor: SettingsCatalog.bars.kiwishelfCard.id
                )
        )
        #expect(
            SettingsAnchor(landing: .looks)
                == SettingsAnchor(destination: .looks)
        )
        #expect(
            SettingsAnchor(landing: .advancedColors)
                == SettingsAnchor(destination: .advancedColors)
        )
    }

    /// A Space's card is a surface of Spaces alone: the reveal
    /// keeps it there and nowhere else.
    @Test("a Space landing opens that Space's card on Spaces")
    func spaceLanding() throws {
        let space = SpaceID("3")
        let anchor = SettingsAnchor(landing: .space(space))
        let resolved = try #require(
            anchor.resolved(editingStoredProfile: false)
        )
        #expect(resolved.destination == .spaces)
        #expect(resolved.surface == .space(space))
        let stray = SettingsAnchor(
            destination: .bars,
            surface: .space(space)
        )
        #expect(
            stray.resolved(editingStoredProfile: false)?.surface == .main
        )
    }

    private func dirtyModel() -> SettingsModel {
        let core = makeTestCore()
        try? core.guiConfigStore.save(GuiConfig())
        let model = makeTestModel(core: core)
        model.reload()
        model.config.settings.kiwishelf.minimum += 5
        return model
    }

    /// A dirty draft takes the menu's edit on both sides of its
    /// diff: the value is the menu's, and the user's own edit is
    /// still the only one it counts.
    @Test("a dirty draft takes a live write without counting it")
    func dirtyDraftTakesTheWrite() {
        let model = dirtyModel()
        #expect(model.isDirty)
        let before = model.draftChangeCount
        model.adoptLiveWrite { $0.spaceBarStyle.glyphSpan = 7 }
        #expect(model.config.settings.spaceBarStyle.glyphSpan == 7)
        #expect(model.cleanConfig.settings.spaceBarStyle.glyphSpan == 7)
        #expect(model.isDirty)
        #expect(model.draftChangeCount == before)
    }

    /// A stored profile's draft is another file, which the write
    /// did not reach: it keeps what it holds.
    @Test("a stored profile's draft ignores a live write")
    func storedDraftIgnoresTheWrite() {
        let model = dirtyModel()
        model.target = .storedProfile("Other")
        let span = model.config.settings.spaceBarStyle.glyphSpan
        model.adoptLiveWrite { $0.spaceBarStyle.glyphSpan = span + 2 }
        #expect(model.config.settings.spaceBarStyle.glyphSpan == span)
    }

    /// A clean draft re-reads what the write left behind rather than
    /// taking the edit by hand.
    @Test("a clean draft re-reads after a live write")
    func cleanDraftReloads() throws {
        let core = makeTestCore()
        try core.guiConfigStore.save(GuiConfig())
        let model = makeTestModel(core: core)
        model.reload()
        #expect(!model.isDirty)
        let loaded = model.config.settings.kiwishelf.minimum
        // A value no file holds, left clean: only a re-read drops it.
        model.suppressDirty = true
        model.config.settings.kiwishelf.minimum = loaded + 9
        model.suppressDirty = false
        model.adoptLiveWrite { _ in }
        #expect(model.config.settings.kiwishelf.minimum == loaded)
    }
}
