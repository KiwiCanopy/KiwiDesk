import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The quick menu's chord providers default to `{ nil }`, a
/// fallback that answers for a forgotten wire — the row shows no
/// chord (or `⌘,`) forever and the keyDown twin-drop never engages,
/// with no test red (#1381, #3470). So the wiring is pinned where
/// it lives.
@Suite("Status menu chord providers are wired")
struct StatusMenuProviderWiringTests {
    @Test("AppDelegate wires each provider by its own verb")
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
                "statusItem.settingsComboProvider={"
            )
        )
        #expect(
            squashed.contains("lua:KeybindingCatalog.openSettings.lua")
        )
        // The Desktop overview row's chord (#3470).
        #expect(
            squashed.contains(
                "statusItem.overviewComboProvider={[weakself]in"
                    + "guardletselfelse{returnnil}"
                    + "returnShortcutsOpenBinding.combo("
                    + "core:self.core,"
                    + "lua:KeybindingCatalog.showDesktopOverview.lua)}"
            )
        )
    }

    /// The overview row and the View side's hold read both default
    /// inert, so a lost wire leaves the row dead and the View
    /// side's chips live before tiling with no test red (#2309,
    /// #3485).
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
                "statusItem.onOpenDesktopOverview={[weakjumpPanel]in"
                    + "jumpPanel?.toggle(.desktops)}"
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
