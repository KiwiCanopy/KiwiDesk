import Foundation
import Testing

@testable import KiwiDesk

/// The call sites that hand the per-screen readings on (#2792):
/// each parameter defaults empty, so a dropped argument compiles
/// and every behavioural suite stays green.
@Suite("Desktop number wiring")
struct DesktopNumberWiringTests {
    private static func squashed(_ path: String) throws -> String {
        try SourceScan.blankedSource(
            at: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(path)
        ).split(whereSeparator: \.isWhitespace).joined()
    }

    @Test("each reading reaches its surface")
    func readingsAreWired() throws {
        let cue = try Self.squashed(
            "Sources/KiwiDeskCore/Profiles/KiwiCore+DesktopCue.swift"
        )
        #expect(cue.contains("screen:display.flatMap(screenLabel),"))
        let card = try Self.squashed(
            "Sources/KiwiDesk/Settings/Components/Profiles/DesktopsGroup.swift"
        )
        #expect(card.contains("screenNumbers:model.desktopScreenNumbers,"))
        let row = try Self.squashed(
            "Sources/KiwiDesk/Settings/Components/Profiles/"
                + "DesktopsGroup+Row.swift"
        )
        #expect(row.contains("row.shownNumber"))
        let draft = try Self.squashed(
            "Sources/KiwiDesk/Settings/Components/Keybindings/"
                + "ShortcutsFamilyRows+Draft.swift"
        )
        #expect(draft.contains("landings:model.desktopLandings"))
        let hub = try Self.squashed(
            "Sources/KiwiDesk/Jump/JumpPanelController+Shortcuts.swift"
        )
        #expect(hub.contains("landings:core.desktopLandings(in:desktops),"))
        let refresh = try Self.squashed(
            "Sources/KiwiDesk/Settings/SettingsModel+Refresh.swift"
        )
        #expect(
            refresh.contains(
                "desktopLandings=core.desktopLandings(in:desktops)"
            )
        )
        #expect(
            refresh.contains(
                "desktopScreenNumbers=desktops.screenNumbersByKey"
            )
        )
    }
}
