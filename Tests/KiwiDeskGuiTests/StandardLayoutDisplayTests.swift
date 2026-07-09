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

    @Test("a Standard's display name and summary resolve to German")
    func displayNameResolvesGerman() throws {
        reset()
        LocalizationManager.shared.select("de")
        defer { reset() }
        let layout = try #require(
            StandardProfiles.all.first { $0.name == "Developer" }
        )
        // The stable identity never changes.
        #expect(layout.name == "Developer")
        #expect(layout.displayName == "Developer")
        #expect(
            layout.displaySummary
                == "IDE-Stapel, scrollende Dokumentation und "
                + "ein Vollbild-Vorschau-Space."
        )
    }

    @Test("standardDisplayName resolves a bare name to German")
    func standardDisplayNameResolvesGerman() {
        reset()
        LocalizationManager.shared.select("de")
        defer { reset() }
        #expect(
            standardDisplayName("Command Center")
                == "Command Center"
        )
        #expect(
            standardDisplayName("Coder & Monitor")
                == "Coder & Monitor"
        )
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
