import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The keys step introduces KiwiHub and KiwiVision (#2515): KiwiHub
/// is the last row, its bound sides in J K L order and the gateway;
/// KiwiVision a row of its own; and a bar set to Always is left out
/// of the bars row (owner, 2026-10-23).
@Suite("Onboarding KiwiHub and KiwiVision keys (#2515)")
@MainActor
struct OnboardingKeysHubTests {
    private func layer(_ bindings: [(String, String)]) -> KeyLayer {
        var layer = KeyLayer.defaultLayer
        layer.bindings = bindings.map { combo, lua in
            KeyBinding(
                combo: combo,
                lua: lua,
                kind: .navigation,
                label: lua
            )
        }
        return layer
    }

    private let hub: [(String, String)] = [
        ("control+option+j", KiwiHubSide.windows.lua),
        ("control+option+k", KiwiHubSide.shortcuts.lua),
        ("control+option+l", KiwiHubSide.view.lua),
    ]

    @Test("KiwiHub is the last row, its three sides in J K L order")
    func hubRowNamesItsSides() {
        LocalizationManager.shared.select("en")
        let families = OnboardingKeys.families(
            layer: layer(
                hub + [
                    (
                        "control+option+v",
                        KeybindingCatalog.toggleKiwiVision.lua
                    )
                ]
            ),
            spaces: []
        )
        let row = families.last
        #expect(row?.id == "kiwihub")
        #expect(row?.isGateway == true)
        #expect(
            row?.chord == .shared([.control, .option], keys: "J K L")
        )
        #expect(row?.label == "KiwiHub: Windows, Shortcuts, and View")
        #expect(row?.tier == nil)
        // Each side beside its own chord, never left to position.
        let spoken = row?.spoken ?? ""
        #expect(spoken.hasPrefix("KiwiHub"))
        #expect(spoken.contains("Windows ⌃⌥J"))
        #expect(spoken.contains("View ⌃⌥L"))
    }

    @Test("an unbound side is left out, and no side means no row")
    func hubRowShrinks() {
        LocalizationManager.shared.select("en")
        let one = OnboardingKeys.kiwiHubFamily(layer: layer([hub[1]]))
        #expect(one?.label == "KiwiHub: Shortcuts")
        #expect(one?.chord == .shared([.control, .option], keys: "K"))
        #expect(OnboardingKeys.kiwiHubFamily(layer: layer([])) == nil)
    }

    @Test("a bound KiwiVision is taught, an unbound one is not")
    func kiwiVisionIsTaught() {
        let taught = OnboardingKeys.families(
            layer: layer([
                ("control+option+v", KeybindingCatalog.toggleKiwiVision.lua)
            ]),
            spaces: []
        )
        let row = taught.first { $0.id == "kiwivision" }
        #expect(row?.chord == .shared([.control, .option], keys: "V"))
        #expect(row?.tier == nil)
        let untaught = OnboardingKeys.families(
            layer: layer(hub),
            spaces: []
        )
        #expect(!untaught.contains { $0.id == "kiwivision" })
    }

    private let bars: [(String, String)] = [
        ("control+option+g", KeybindingCatalog.toggleSpaceBar.lua),
        ("control+option+h", KeybindingCatalog.toggleAppBar.lua),
    ]

    @Test("a bar set to Always is left out of the bars row")
    func alwaysBarIsLeftOut() {
        LocalizationManager.shared.select("en")
        let both = OnboardingKeys.families(
            layer: layer(bars),
            spaces: [],
            showsBar: { _ in false }
        )
        #expect(!both.contains { $0.id == "bars" })
        #expect(!both.contains { $0.id.contains("toggle_reveal") })
        let spaceOnly = OnboardingKeys.families(
            layer: layer(bars),
            spaces: [],
            showsBar: { $0 == .space }
        )
        let row = spaceOnly.first { $0.id.contains("toggle_reveal") }
        #expect(
            row?.label == KeybindingCatalog.toggleSpaceBar.resolvedLabel
        )
    }

    /// The keys step reads the bars' visibility the bars step just
    /// wrote, through the shortcut's own gate.
    @Test("the tour hands the keys step the live visibility")
    func showsBarIsWired() throws {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/AppDelegate+Onboarding.swift"
            )
        let source = SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        )
        #expect(
            source.contains(
                "showsBar: { settings.revealActionLiveAnywhere($0) }"
            )
        )
        #expect(source.contains("let settings = core.tiler.settings"))
    }
}
