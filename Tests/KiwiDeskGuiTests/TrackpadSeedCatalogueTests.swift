import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// Each trackpad gesture seed runs a Shortcuts catalogue row's own
/// Lua (#1873), so a row that recognizes a catalogue action by its
/// text knows it — `focus_space_last` included, which no keyboard
/// default binds (#3206).
@Suite("Trackpad seeds are catalogue rows")
@MainActor
struct TrackpadSeedCatalogueTests {
    @Test("every seed's action is a catalogue row")
    func seedsAreCatalogueRows() {
        let rows = KeybindingCatalog.namedCommands(
            spaces: [SpaceID("1")],
            layerNames: [],
            steps: [50],
            bindings: []
        )
        let catalogue = Set(rows.map(\.lua))
        #expect(!TrackpadGestureSeeds.seeds.isEmpty)
        #expect(!catalogue.isEmpty)
        for (slot, binding) in TrackpadGestureSeeds.seeds {
            #expect(catalogue.contains(binding.action), "\(slot)")
        }
    }
}
