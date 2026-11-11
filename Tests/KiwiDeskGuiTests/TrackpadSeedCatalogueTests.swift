import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// Each Lua gesture seed runs a Shortcuts catalogue row's own Lua
/// (#1873, #3199), so a row that recognizes a catalogue action by
/// its text knows it — `focus_space_last` included, which no
/// keyboard default binds (#3206).
@Suite("Gesture seeds are catalogue rows")
@MainActor
struct TrackpadSeedCatalogueTests {
    @Test("every Lua seed's action is a catalogue row")
    func seedsAreCatalogueRows() {
        let rows = KeybindingCatalog.namedCommands(
            spaces: [SpaceID("1")],
            layerNames: [],
            steps: [50],
            bindings: []
        )
        let catalogue = Set(rows.map(\.lua))
        #expect(!catalogue.isEmpty)
        var checked = 0
        for (key, action) in GestureSeeds.seeds {
            guard case .run(let lua) = action else { continue }
            checked += 1
            #expect(catalogue.contains(lua.lua), "\(key.spelling)")
        }
        #expect(checked >= 2)
    }
}
