import Foundation
import Testing

@testable import KiwiDeskCore

/// `grid.set_column_weight` / `grid.set_row_weight` and their
/// `_override` siblings (#763): the authored weights a resize's
/// session layer sits over, and the explicit writes that drop that
/// layer so they visibly apply (#383, #764).
@Suite("Grid weight verbs (#763)")
@MainActor
struct GridWeightCommandTests {
    private func makeCore() -> KiwiCore {
        makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent(
                    "kiwi-grid-weight-\(UUID().uuidString)"
                )
        )
    }

    private func sessionColumns(_ core: KiwiCore) -> [Double]? {
        core.state.workspaces[SpaceID("1")]?.sessionRatios
            .gridColumnWeights
    }

    private func seedSession(_ core: KiwiCore) {
        core.state.workspaces.withSpace(SpaceID("1")) {
            $0.sessionRatios.gridColumnWeights = [1.5, 0.5]
            $0.sessionRatios.gridRowWeights = [2]
        }
    }

    @Test("A column weight counts from 1 and pads with equal shares")
    func setsOneColumn() {
        let core = makeCore()
        let response = core.execute(
            "grid.set_column_weight",
            args: [.number(3), .number(2)]
        )
        #expect(response.isSuccess)
        #expect(core.tiler.settings.grid.columnWeights == [1, 1, 2])
    }

    @Test("Setting every share back to 1 empties the list")
    func equalLeavesTheFile() {
        let core = makeCore()
        core.execute("grid.set_row_weight", args: [.number(2), .number(3)])
        core.execute("grid.set_row_weight", args: [.number(2), .number(1)])
        #expect(core.tiler.settings.grid.rowWeights.isEmpty)
    }

    @Test("A zero, negative or missing weight is refused")
    func refusesBadInput() {
        let core = makeCore()
        for args: [JSONValue] in [
            [.number(1), .number(0)],
            [.number(1), .number(-2)],
            [.number(0), .number(2)],
            [.number(1)],
        ] {
            #expect(
                !core.execute("grid.set_column_weight", args: args)
                    .isSuccess
            )
        }
        #expect(core.tiler.settings.grid.columnWeights.isEmpty)
    }

    @Test("The global setter drops every Space's session layer")
    func globalClearsSession() {
        let core = makeCore()
        seedSession(core)
        core.execute(
            "grid.set_column_weight",
            args: [.number(1), .number(2)]
        )
        #expect(sessionColumns(core) == nil)
        // The other axis's layer is not this verb's.
        #expect(
            core.state.workspaces[SpaceID("1")]?.sessionRatios
                .gridRowWeights == [2]
        )
    }

    @Test("The override setter drops that Space's session layer")
    func overrideClearsItsShadow() {
        let core = makeCore()
        core.execute(
            "grid.set_column_weight",
            args: [.number(1), .number(3)]
        )
        seedSession(core)
        let response = core.execute(
            "grid.set_column_weight_override",
            args: [.string("1"), .number(2), .number(2)]
        )
        #expect(response.isSuccess)
        #expect(sessionColumns(core) == nil)
        // Starts from what the Space resolved to.
        #expect(
            core.tiler.settings.grid.override[SpaceID("1")]?
                .columnWeights == [3, 2]
        )
        #expect(core.tiler.settings.grid.columnWeights == [3])
    }

    @Test("The weights encode under the Lua-derived keys")
    func jsonKeys() throws {
        var grid = GridParams()
        let empty =
            try JSONSerialization.jsonObject(
                with: JSONEncoder().encode(grid)
            ) as? [String: Any]
        #expect(empty?["column_weight"] == nil)
        grid.columnWeights = [2, 1]
        grid.rowWeights = [1, 3]
        let data = try JSONEncoder().encode(grid)
        let object =
            try JSONSerialization.jsonObject(with: data)
            as? [String: Any]
        #expect(object?["column_weight"] as? [Double] == [2, 1])
        #expect(object?["row_weight"] as? [Double] == [1, 3])
        let back = try JSONDecoder().decode(GridParams.self, from: data)
        #expect(back == grid)
    }
}
