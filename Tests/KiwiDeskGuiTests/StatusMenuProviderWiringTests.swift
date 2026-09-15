import Foundation
import Testing

@testable import KiwiDesk

/// The quick menu's two chord providers default to `{ nil }`, a
/// fallback that answers for a forgotten wire — the row shows
/// `⌘,` forever and the keyDown twin-drop never engages, with no
/// test red (#1381). So the wiring is pinned where it lives.
@Suite("Status menu chord providers are wired")
struct StatusMenuProviderWiringTests {
    @Test("AppDelegate wires both providers by their own verb")
    func providersAreWired() throws {
        let source = try SourceScan.strippedSource(
            at: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(
                    "Sources/KiwiDesk/AppDelegate.swift"
                )
        )
        let squashed = source.split(whereSeparator: \.isWhitespace)
            .joined()
        #expect(
            squashed.contains(
                "statusItem.shortcutsComboProvider={"
            )
        )
        #expect(
            squashed.contains(
                "statusItem.settingsComboProvider={"
            )
        )
        #expect(squashed.contains("lua:ShortcutsOpenBinding.lua"))
        #expect(
            squashed.contains("lua:KeybindingCatalog.openSettings.lua")
        )
    }
}
