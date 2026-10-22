import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The bar show/hide and maximize chords the tour teaches (#2515),
/// read from the live layer: the bars step lists each bar's chord
/// under the catalog's own words, and the keys step folds both
/// into one row beside a maximize row.
@Suite("Onboarding bar and maximize keys (#2515)")
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

    @Test("the keys step folds both bars into one row")
    func keysStepFoldsBars() {
        let families = OnboardingKeys.families(
            layer: layer([space, app, maximize]),
            spaces: []
        )
        let bars = families.filter {
            $0.id == "bars" || $0.id.contains("toggle_reveal")
        }
        #expect(bars.count == 1)
        #expect(
            bars.first?.chord
                == .shared([.control, .option], keys: "G H")
        )
        #expect(bars.first?.tier == nil)
    }

    @Test("one bound bar keeps its own label on the keys step")
    func singleBarKeepsItsLabel() {
        let bars = OnboardingKeys.revealFamily(layer: layer([space]))
        #expect(
            bars?.label
                == KeybindingCatalog.toggleSpaceBar.resolvedLabel
        )
        #expect(OnboardingKeys.revealFamily(layer: layer([])) == nil)
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
