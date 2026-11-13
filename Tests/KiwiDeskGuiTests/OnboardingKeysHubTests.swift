import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The keys step introduces KiwiHub and KiwiVision (#2515): KiwiHub
/// is the last row, its bound sides in J K L O order and the
/// gateway; KiwiVision a row of its own.
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

    @Test("KiwiHub is the last row, its bound sides in J K L O order")
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

    /// The seeded ⌃⌥O (#3167) joins the J K L collapse, and a ⌘⌘ the
    /// user set stands on its own keycap after it (#1229).
    @Test("the seeded overview chord joins J K L; a set tap stands apart")
    func seededOverviewCollapses() {
        LocalizationManager.shared.select("en")
        var seeded = KeyLayer.defaultLayer
        seeded.bindings = DefaultKeybindings.bindings(
            spaces: [],
            resizeStep: 50,
            base: .standard
        )
        let row = OnboardingKeys.kiwiHubFamily(layer: seeded)
        #expect(
            row?.chord == .shared([.control, .option], keys: "J K L O")
        )
        #expect(
            row?.label == "KiwiHub: Windows, Shortcuts, View, and Desktops"
        )
        seeded.bindings = seeded.bindings.map {
            guard $0.lua == KiwiHubSide.desktops.lua else { return $0 }
            var tap = $0
            tap.combo = "cmd+cmd"
            return tap
        }
        let tapped = OnboardingKeys.kiwiHubFamily(layer: seeded)
        #expect(tapped?.chord == .mixed(["⌃⌥ J K L", "⌘⌘"]))
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
}
