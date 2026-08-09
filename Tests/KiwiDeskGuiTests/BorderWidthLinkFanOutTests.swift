import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Borders card's two masters (#754). The gate suite says
/// which rows GREY; this says what the masters WRITE, which no
/// gate can see: a link that dims three sliders and then leaves
/// their stored values alone ships a card whose whole claim —
/// one width for all borders — is false at the pixel.
@MainActor
@Suite("Border width link fan-out")
struct BorderWidthLinkFanOutTests {
    private func model() -> (SettingsModel, UserDefaults) {
        let name = "border-link-fanout-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return (makeTestModel(defaults: defaults), defaults)
    }

    /// Pin the two defaults this suite reasons from: the ring
    /// and the drag pair ship the SAME width, which is what
    /// makes a default-on link honest out of the box (tests.md
    /// — a fixture pins any default it reasons from).
    @Test("the shipped widths already agree")
    func shippedWidthsAgree() {
        let settings = TilingSettings()
        #expect(
            settings.borderStyle.width
                == settings.dragGhost.borderWidth
        )
        #expect(
            settings.borderStyle.width
                == settings.dragDropZone.borderWidth
        )
    }

    @Test("linked, the width master writes all three strokes")
    func linkedWidthFansOut() {
        let (model, _) = model()
        model.setBorderWidthLinked(true)
        model.borderWidthMaster.wrappedValue = 11
        let settings = model.config.settings
        #expect(settings.borderStyle.width == 11)
        #expect(settings.dragGhost.borderWidth == 11)
        #expect(settings.dragDropZone.borderWidth == 11)
    }

    @Test("unlinked, the width master is the ring's alone")
    func unlinkedWidthStaysHome() {
        let (model, _) = model()
        model.setBorderWidthLinked(false)
        let before = model.config.settings.dragGhost.borderWidth
        model.borderWidthMaster.wrappedValue = 11
        let settings = model.config.settings
        #expect(settings.borderStyle.width == 11)
        #expect(settings.dragGhost.borderWidth == before)
        #expect(settings.dragDropZone.borderWidth == before)
    }

    /// Linking is not just a dim: it converges the strokes then
    /// and there, so the greyed sliders under it are not left
    /// showing a width the master does not own.
    @Test("turning the link on converges the strokes")
    func linkingConverges() {
        let (model, _) = model()
        model.setBorderWidthLinked(false)
        model.config.settings.dragGhost.borderWidth = 2
        model.config.settings.dragDropZone.borderWidth = 17
        model.borderWidthMaster.wrappedValue = 7
        model.setBorderWidthLinked(true)
        let settings = model.config.settings
        #expect(settings.dragGhost.borderWidth == 7)
        #expect(settings.dragDropZone.borderWidth == 7)
    }

    /// Unlinking is a statement about FUTURE edits, not a
    /// reset — so the fixture has to be a draft the link would
    /// change if unlinking re-derived: strokes that diverged
    /// while the link was on, which is what a profile Lua wrote
    /// arrives as.
    @Test("turning the link off changes no stored width")
    func unlinkingChangesNothing() {
        let (model, _) = model()
        model.setBorderWidthLinked(true)
        model.borderWidthMaster.wrappedValue = 9
        model.config.settings.dragGhost.borderWidth = 2
        model.config.settings.borderStyle.cornerStyle = .square
        let before = model.config.settings
        #expect(before.dragCornerRadius > 0)
        model.setBorderWidthLinked(false)
        #expect(model.config.settings == before)
    }

    /// The ring has no radius, so the corner master reaches it
    /// as the only thing its two-value picker can say.
    @Test("linked, the corner master derives the ring's shape")
    func linkedCornerDerives() {
        let (model, _) = model()
        model.setBorderWidthLinked(true)
        model.borderCornerMaster.wrappedValue = 0
        #expect(
            model.config.settings.borderStyle.cornerStyle
                == .square
        )
        model.borderCornerMaster.wrappedValue = 12
        #expect(
            model.config.settings.borderStyle.cornerStyle
                == .rounded
        )
    }

    @Test("unlinked, the corner master leaves the ring alone")
    func unlinkedCornerStaysHome() {
        let (model, _) = model()
        model.setBorderWidthLinked(false)
        model.config.settings.borderStyle.cornerStyle = .rounded
        model.borderCornerMaster.wrappedValue = 0
        #expect(
            model.config.settings.dragCornerRadius == 0
        )
        #expect(
            model.config.settings.borderStyle.cornerStyle
                == .rounded
        )
    }

    /// The pick reaches the injected domain, not `.standard` —
    /// and the model reads it back at init, which is the whole
    /// of its persistence.
    @Test("the pick persists through the injected domain")
    func pickPersists() {
        let (model, defaults) = model()
        model.setBorderWidthLinked(false)
        #expect(
            BorderWidthLinkPreference.read(from: defaults)
                == false
        )
        let reopened = makeTestModel(defaults: defaults)
        #expect(!reopened.borderWidthLinked)
    }
}
