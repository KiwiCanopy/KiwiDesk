import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The gesture cards' save-pill rows and their ↺ (#3183): a re-key
/// is one row naming both keys, reverted together, and a stored
/// change with no change of action still gets its row. Main-actor
/// spend: two test models.
@Suite("Gesture diff rows (#3183)")
@MainActor
struct GestureDiffRowsTests {
    private let from = GestureKey(.wheel, [.control, .option])
    private let to = GestureKey(.wheel, [.control, .shift])

    private func moved() -> GestureMap {
        var base = GestureMap()
        #expect(GestureListEdits.rekey(from, to: to, in: &base))
        return base
    }

    @Test("a re-key narrates as one row naming both keys")
    func moveIsOneRow() throws {
        LocalizationManager.shared.select("en")
        let rows = SettingsValueReadout.gestureRows(
            old: GestureMap(),
            new: moved()
        )
        #expect(rows.count == 1)
        let row = try #require(rows.first)
        let move = GestureRowInstance.move(from: from, to: to)
        #expect(row.id.contains(move.spelling))
        #expect(GestureRowInstance(instance: move.spelling) == move)
    }

    @Test("a move row's revert takes both keys back")
    func moveRevertsTogether() throws {
        let model = makeTestModel()
        model.cleanConfig.gesture = GestureMap()
        model.config.gesture = moved()
        let writer = try #require(
            SettingsRevertRegister.writers[.shortcuts(.gestureBindings)]
        )
        writer.apply(
            model,
            GestureRowInstance.move(from: from, to: to).spelling
        )
        #expect(model.config.gesture == GestureMap())
    }

    @Test("a stored change that keeps the action still gets a row")
    func rawChangeIsNarrated() {
        var old = GestureMap()
        let seed = GestureListEdits.action(of: from, in: old)!
        old[from] = .bound(seed)
        let rows = SettingsValueReadout.gestureRows(
            old: old,
            new: GestureMap()
        )
        #expect(rows.count == 1)
    }
}
