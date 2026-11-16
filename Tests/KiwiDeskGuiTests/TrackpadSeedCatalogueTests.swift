import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// Each Lua gesture seed runs a Shortcuts catalogue row's own Lua
/// (#1873, #3199), so a row that recognizes a catalogue action by
/// its text knows it — `focus_space_last` included, which no
/// keyboard default binds (#3206) — and so does each arm of a split
/// seed: a direction's own Lua, and each step an axis family takes
/// (#1873 ▸ Ruling 2026-11-15).
@Suite("Gesture seeds are catalogue rows")
@MainActor
struct TrackpadSeedCatalogueTests {
    private var catalogue: Set<String> {
        let rows = KeybindingCatalog.namedCommands(
            spaces: [SpaceID("1")],
            layerNames: [],
            steps: [50],
            bindings: []
        )
        return Set(rows.map(\.lua))
    }

    @Test("every Lua seed's action is a catalogue row")
    func seedsAreCatalogueRows() {
        let catalogue = catalogue
        #expect(!catalogue.isEmpty)
        var checked = 0
        for (key, action) in GestureSeeds.seeds {
            guard case .run(let lua) = action else { continue }
            checked += 1
            #expect(catalogue.contains(lua.lua), "\(key.spelling)")
        }
        #expect(checked >= 2)
    }

    @Test("every split seed's arm and axis step is a catalogue row")
    func splitArmsAreCatalogueRows() {
        let catalogue = catalogue
        var arms = 0
        var axes = 0
        for (key, action) in GestureSeeds.seeds {
            guard case .split(let split) = action else { continue }
            for (direction, arm) in split.arms {
                arms += 1
                #expect(
                    catalogue.contains(arm.lua),
                    "\(key.spelling) \(direction)"
                )
            }
            for (axis, family) in split.axes {
                for direction in axis.directions {
                    axes += 1
                    #expect(
                        catalogue.contains(family.lua(direction)),
                        "\(key.spelling) \(axis) \(direction)"
                    )
                }
            }
        }
        #expect(arms >= 1)
        #expect(axes >= 2)
    }

    /// A family seed's one-shot step each way is a catalogue row
    /// too, rotate's layout pair included (#1873 ▸ owner ruling
    /// 2026-11-15), so the panel badges the row it runs.
    @Test("every family seed's step is a catalogue row")
    func familyStepsAreCatalogueRows() {
        let catalogue = catalogue
        var checked = 0
        for (key, action) in GestureSeeds.seeds {
            // Focus and the walk run the pan, and a screen step by
            // direction has no keyboard row: the panel lists it
            // under Gestures.
            guard case .family(let family) = action,
                ![.focus, .walk, .display].contains(family)
            else { continue }
            for direction in key.input.directions {
                checked += 1
                #expect(
                    catalogue.contains(family.lua(direction)),
                    "\(key.spelling) \(direction)"
                )
            }
        }
        #expect(checked >= 6)
    }
}
