import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// Pins the Presets-list localization gap found alongside the
/// keybinding audit: `StandardLayout.name` stays the stable
/// English identity that seeds a new saved profile's name
/// (`freeName(base: layout.name)`) and labels `activeStandard`;
/// only `displayName`/`displaySummary` (and the
/// `standardDisplayName(_:)` lookup used by `ProfileHeader`)
/// translate. `.serialized` mirrors `LocalizationManagerTests`
/// (`LocalizationManager` is a process-wide singleton).
@Suite("Standard layout display localization", .serialized)
@MainActor
struct StandardLayoutDisplayTests {
    private func reset() {
        LocalizationManager.shared.select(nil)
    }

    // These tests assert the localization SEAM, not specific
    // German text: English shows the canonical identity, a
    // selected locale resolves away from it. The exact
    // translations are translator-owned content (refined freely
    // in the locale files) and must not be pinned here, or every
    // wording tweak reddens the suite.
    @Test("a Standard's display name and summary localize")
    func displayNameLocalizes() throws {
        reset()
        let layout = try #require(
            StandardProfiles.all.first { $0.name == "Developer" }
        )
        // Explicit English (not System default) → canonical.
        LocalizationManager.shared.select("en")
        #expect(layout.displayName == layout.name)
        #expect(layout.displaySummary == layout.summary)
        // German → localized away from the canonical English,
        // while the stable identity never changes.
        LocalizationManager.shared.select("de")
        defer { reset() }
        #expect(layout.name == "Developer")
        #expect(layout.displayName != layout.name)
        #expect(layout.displaySummary != layout.summary)
    }

    @Test("standardDisplayName localizes a bare name")
    func standardDisplayNameLocalizes() {
        reset()
        LocalizationManager.shared.select("en")
        #expect(standardDisplayName("Command Center") == "Command Center")
        LocalizationManager.shared.select("de")
        defer { reset() }
        // Shipped German translates the Standard names; assert it
        // resolved away from English, not the exact wording.
        #expect(standardDisplayName("Command Center") != "Command Center")
        #expect(standardDisplayName("Coder & Monitor") != "Coder & Monitor")
    }

    @Test("an unknown name passes through unchanged")
    func unknownNamePassesThrough() {
        reset()
        LocalizationManager.shared.select("de")
        defer { reset() }
        #expect(
            standardDisplayName("A Hand-Edited Profile")
                == "A Hand-Edited Profile"
        )
    }
}
