import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The shared card's two masters (#754). Nothing else can see
/// what they WRITE: the census records two rows, the gate suite
/// records no gate on them, and a master that moves one stroke
/// and leaves the other two ships a card whose whole claim —
/// one width and one corner for every border — is false at the
/// pixel.
@MainActor
@Suite("Border masters fan-out")
struct BorderMastersFanOutTests {
    private func model() -> SettingsModel {
        let name = "border-masters-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return makeTestModel(defaults: defaults)
    }

    /// Pin the defaults this suite reasons from: all three
    /// strokes ship the SAME width, and the drag pair's radius
    /// ships at the very constant Rounded writes, so an
    /// untouched config already agrees with what the two rows
    /// show and neither master has to write to make it true
    /// (tests.md — a fixture pins any default it reasons from).
    @Test("the shipped strokes already agree")
    func shippedStrokesAgree() {
        let settings = TilingSettings()
        #expect(
            settings.borderStyle.width
                == settings.dragGhost.borderWidth
        )
        #expect(
            settings.borderStyle.width
                == settings.dragDropZone.borderWidth
        )
        #expect(
            settings.dragCornerRadius
                == GeometryUtils.systemWindowCornerRadius
        )
    }

    @Test("the width master writes all three strokes")
    func widthFansOut() {
        let model = model()
        model.borderWidthMaster.wrappedValue = 11
        let settings = model.config.settings
        #expect(settings.borderStyle.width == 11)
        #expect(settings.dragGhost.borderWidth == 11)
        #expect(settings.dragDropZone.borderWidth == 11)
    }

    /// Square is the ring's square style AND a zero radius;
    /// Rounded is the ring's rounded style AND the system window
    /// radius. Two stored shapes, one decision.
    @Test("the corner master writes all three strokes")
    func cornersFanOut() {
        let model = model()
        model.borderCornersMaster.wrappedValue = .square
        #expect(
            model.config.settings.borderStyle.cornerStyle
                == .square
        )
        #expect(model.config.settings.dragCornerRadius == 0)
        model.borderCornersMaster.wrappedValue = .rounded
        #expect(
            model.config.settings.borderStyle.cornerStyle
                == .rounded
        )
        #expect(
            model.config.settings.dragCornerRadius
                == GeometryUtils.systemWindowCornerRadius
        )
    }

    /// The picker READS the radius, so any radius above zero
    /// shows as Rounded — the drag pair really does draw rounded
    /// corners at 7 pt, and a picker showing Square there would
    /// describe neither stroke.
    @Test("a radius the GUI never set reads as Rounded")
    func anyPositiveRadiusReadsRounded() {
        let model = model()
        model.config.settings.dragCornerRadius = 7
        #expect(model.borderCornersMaster.wrappedValue == .rounded)
        model.config.settings.dragCornerRadius = 0
        #expect(model.borderCornersMaster.wrappedValue == .square)
    }

    /// The residue, pinned so it stays deliberate: READING the
    /// master never stores. A profile Lua gave a 7 pt radius and
    /// a square ring arrives disagreeing with itself, and it
    /// STAYS that way until the user picks a segment — nothing
    /// re-derives it at load, because that would rewrite a saved
    /// profile the user never opened this card to change.
    @Test("reading the masters rewrites nothing")
    func readingDoesNotWrite() {
        let model = model()
        model.config.settings.dragCornerRadius = 7
        model.config.settings.borderStyle.cornerStyle = .square
        model.config.settings.dragGhost.borderWidth = 2
        let before = model.config.settings
        _ = model.borderCornersMaster.wrappedValue
        _ = model.borderWidthMaster.wrappedValue
        #expect(model.config.settings == before)
    }
}
