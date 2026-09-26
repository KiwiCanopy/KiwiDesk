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
            StandardProfiles.workflows.first {
                $0.name == "Developer"
            }
        )
        // Explicit English (not System default) → canonical.
        LocalizationManager.shared.select("en")
        #expect(layout.displayName == layout.name)
        // `summary` left Core in #601 — the GUI owns preset copy
        // now, so the English rendering is the catalog's, not a
        // Core-held duplicate to compare against. Capture it and
        // require the locale to move it.
        let englishSummary = layout.displaySummary
        #expect(!englishSummary.isEmpty)
        // German → localized away from the canonical English,
        // while the stable identity never changes.
        LocalizationManager.shared.select("de")
        defer { reset() }
        #expect(layout.name == "Developer")
        #expect(layout.displayName != layout.name)
        #expect(layout.displaySummary != englishSummary)
    }

    @Test("standardDisplayName localizes a bare name")
    func standardDisplayNameLocalizes() {
        reset()
        LocalizationManager.shared.select("en")
        #expect(
            standardDisplayName("Command Center", title: nil)
                == "Command Center"
        )
        LocalizationManager.shared.select("de")
        defer { reset() }
        // Shipped German translates the Standard names; assert it
        // resolved away from English, not the exact wording.
        #expect(
            standardDisplayName("Command Center", title: nil)
                != "Command Center"
        )
        #expect(
            standardDisplayName("Coder & Monitor", title: nil)
                != "Coder & Monitor"
        )
    }

    @Test("an unknown name passes through unchanged")
    func unknownNamePassesThrough() {
        reset()
        LocalizationManager.shared.select("de")
        defer { reset() }
        #expect(
            standardDisplayName("A Hand-Edited Profile", title: nil)
                == "A Hand-Edited Profile"
        )
    }

    /// One screen is named; several are not, since no one class
    /// describes them (#1662).
    @Test("the onboarding heading names a single screen only")
    func onboardingHeading() {
        reset()
        LocalizationManager.shared.select("en")
        defer { reset() }
        #expect(
            StarterTitle(shape: .ultrawide, otherScreens: 0)
                .onboardingTitle
                == "Your Spaces are ready for your ultrawide screen"
        )
        #expect(
            StarterTitle(shape: .ultrawide, otherScreens: 1)
                .onboardingTitle
                == "Your Spaces are ready for all your screens"
        )
    }

    /// The starter answers with its title, never its identity
    /// (#1662): the header and which-loads read this path.
    @Test("the starter's name resolves to its title")
    func starterNameShowsTitle() {
        reset()
        LocalizationManager.shared.select("en")
        defer { reset() }
        let title = StarterTitle(shape: .ultrawide, otherScreens: 1)
        #expect(
            standardDisplayName(StarterSetup.name, title: title)
                == "Ultrawide + 1"
        )
    }
}
