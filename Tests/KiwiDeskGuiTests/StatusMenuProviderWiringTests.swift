import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

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
                "statusItem.kiwiHubComboProvider={"
            )
        )
        #expect(
            squashed.contains(
                "statusItem.settingsComboProvider={"
            )
        )
        #expect(squashed.contains("lua:KiwiHubSide.view.lua"))
        #expect(
            squashed.contains("lua:KeybindingCatalog.openSettings.lua")
        )
    }

    /// The Open KiwiHub row and the View side's hold read both
    /// default inert, so a lost wire leaves the row dead and the
    /// chips live before tiling with no test red (#2309).
    @Test("AppDelegate wires the KiwiHub row and the hold")
    func kiwiHubRowIsWired() throws {
        let squashed = try SourceScan.strippedSource(
            at: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(
                    "Sources/KiwiDesk/AppDelegate.swift"
                )
        ).split(whereSeparator: \.isWhitespace).joined()
        #expect(
            squashed.contains(
                "statusItem.onOpenKiwiHub={[weakjumpPanel]in"
                    + "jumpPanel?.toggle(.view)}"
            )
        )
        #expect(
            squashed.contains(
                "jumpPanel.hold={[weakself]inself?.coreHold??.running}"
            )
        )
    }

    @Test("each hold names its own reason, running none")
    @MainActor
    func holdReasons() {
        LocalizationManager.shared.select("en")
        #expect(ViewPickText.held(.running) == nil)
        #expect(ViewPickText.held(.notStarted) == "Tiling hasn't started")
        #expect(
            ViewPickText.held(.permissionMissing)
                == "Needs Accessibility permission"
        )
    }
}
