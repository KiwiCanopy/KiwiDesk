import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The bar show/hide, maximize and Tiling Off chords the tour
/// teaches (#2515, #3287), read from the live layer: the bars step
/// lists each bar's chord under the catalog's own words, and the
/// keys step leaves the bars to it, teaching Tiling Off right after
/// Maximize.
@Suite("Onboarding bar, maximize and Tiling Off keys (#2515)")
@MainActor
struct OnboardingKeysBarsTests {
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

    private let space = (
        "control+option+g", KeybindingCatalog.toggleSpaceBar.lua
    )
    private let app = (
        "control+option+h", KeybindingCatalog.toggleAppBar.lua
    )
    private let maximize = (
        "control+option+m", KeybindingCatalog.maximize.lua
    )
    private let tilingOff = (
        "control+option+t", KeybindingCatalog.toggleTiling.lua
    )
    private let pocket = (
        "control+option+p", KeybindingCatalog.pocket.lua
    )

    @Test("the bars step lists each bound bar, Space Bar first")
    func revealRows() {
        let rows = OnboardingKeys.revealFamilies(
            layer: layer([app, space])
        )
        #expect(
            rows.map(\.label) == [
                KeybindingCatalog.toggleSpaceBar.resolvedLabel,
                KeybindingCatalog.toggleAppBar.resolvedLabel,
            ]
        )
        #expect(
            rows.first?.chord == .shared([.control, .option], keys: "G")
        )
    }

    @Test("an unbound bar draws no row")
    func unboundBarHasNoRow() {
        let rows = OnboardingKeys.revealFamilies(layer: layer([app]))
        #expect(rows.map(\.id) == [KeybindingCatalog.toggleAppBar.lua])
        #expect(
            OnboardingKeys.revealFamilies(layer: layer([])).isEmpty
        )
    }

    @Test("the keys step leaves the bars to the bars step")
    func keysStepHasNoBarsRow() {
        let families = OnboardingKeys.families(
            layer: layer([space, app, maximize]),
            spaces: []
        )
        #expect(
            !families.contains {
                $0.id == "bars" || $0.id.contains("toggle_reveal")
            }
        )
    }

    @Test("Tiling Off follows Maximize, in the menu's words")
    func tilingOffFollowsMaximize() {
        LocalizationManager.shared.select("en")
        defer { LocalizationManager.shared.select("en") }
        let families = OnboardingKeys.families(
            layer: layer([pocket, tilingOff, maximize]),
            spaces: []
        )
        #expect(
            families.map(\.id) == ["maximize", "tiling_off", "pocket"]
        )
        let row = families.first { $0.id == "tiling_off" }
        #expect(row?.label == KeybindingCatalog.toggleTiling.resolvedLabel)
        // The menu's words in every catalog, not an English copy.
        LocalizationManager.shared.select("de")
        let german = OnboardingKeys.families(
            layer: layer([tilingOff]),
            spaces: []
        ).first { $0.id == "tiling_off" }
        #expect(german?.label == KeybindingCatalog.toggleTiling.resolvedLabel)
        #expect(german?.label != "Tiling Off for This Space")
        LocalizationManager.shared.select("en")
        #expect(row?.chord == .shared([.control, .option], keys: "T"))
        #expect(row?.tier == nil)
        let untaught = OnboardingKeys.families(
            layer: layer([maximize]),
            spaces: []
        )
        #expect(!untaught.contains { $0.id == "tiling_off" })
    }

    @Test("a bound maximize is taught, an unbound one is not")
    func maximizeIsTaught() {
        let taught = OnboardingKeys.families(
            layer: layer([maximize]),
            spaces: []
        )
        let row = taught.first { $0.id == "maximize" }
        #expect(row?.chord == .shared([.control, .option], keys: "M"))
        #expect(row?.tier == nil)
        let untaught = OnboardingKeys.families(
            layer: layer([space]),
            spaces: []
        )
        #expect(!untaught.contains { $0.id == "maximize" })
    }
}
