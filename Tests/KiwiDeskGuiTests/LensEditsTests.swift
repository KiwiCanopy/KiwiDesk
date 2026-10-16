import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The lens draft's pure halves (#2103 rulings 39, 40): laying a
/// draft over a list keeps a session lens the draft never stored,
/// and a catalog rename lands every rename at once.
@Suite("Lens draft edits (#2103)")
struct LensEditsTests {
    private func named(_ name: String) -> VisionLens {
        VisionLens(name: name)
    }

    @Test("a draft laid over live keeps a session lens, in page order")
    func appliedKeepsSessionLenses() {
        var edits = LensEdits(stored: [named("Writing"), named("Mail")])
        edits.lenses[0].lens.name = "Draft"
        edits.deleted = ["Mail"]
        edits.lenses.remove(at: 1)
        edits.lenses.append(DraftLens(lens: named("New"), stored: nil))
        let live = [named("writing"), named("Mail"), named("Scratch")]
        #expect(
            edits.applied(to: live).map(\.name)
                == ["Draft", "Scratch", "New"]
        )
        let settled = [named("Writing"), named("Mail")]
        #expect(edits.applied(to: settled).map(\.name) == ["Draft", "New"])
    }

    @Test("a lens the draft left as stored keeps its live entry")
    func untouchedLensKeepsLive() {
        var redefined = named("Writing")
        redefined.keepFocus = false
        var edits = LensEdits(stored: [named("Writing"), named("Mail")])
        edits.lenses[1].lens.apps = ["test.kiwi.mail"]
        // A session redefined Writing and deleted Mail.
        let live = [redefined]
        let applied = edits.applied(to: live)
        #expect(applied.map(\.name) == ["Writing", "Mail"])
        #expect(applied.first?.keepFocus == false)
        // Left as stored, a session-deleted lens stays deleted.
        let untouched = LensEdits(stored: [named("Writing"), named("Mail")])
        #expect(untouched.applied(to: live).map(\.name) == ["Writing"])
    }

    @Test("a swap laid over a list merges nothing")
    func appliedSwap() {
        var writing = named("Writing")
        writing.apps = ["test.kiwi.notes"]
        var edits = LensEdits(stored: [writing, named("Reading")])
        edits.lenses[0].lens.name = "Reading"
        edits.lenses[1].lens.name = "Writing"
        let applied = edits.applied(to: edits.seed)
        #expect(applied.map(\.name) == ["Reading", "Writing"])
        #expect(applied.first?.apps == ["test.kiwi.notes"])
    }

    @Test("a draft that changes nothing is inert")
    func inertDraft() {
        let stored = [named("Writing")]
        var edits = LensEdits(stored: stored)
        #expect(edits.isInert(over: stored))
        edits.reach["Writing"] = []
        #expect(!edits.isInert(over: stored))
    }

    @Test("a swap re-keys both chords; a custom label stays")
    func catalogSwap() {
        let writing = KeybindingCatalog.toggleLens("Writing")
        let reading = KeybindingCatalog.toggleLens("Reading")
        let layer = KeyLayer(
            name: KeyLayer.defaultName,
            bindings: [
                KeyBinding(
                    combo: "w",
                    lua: writing.lua,
                    kind: .navigation,
                    label: writing.label
                ),
                KeyBinding(
                    combo: "r",
                    lua: reading.lua,
                    kind: .navigation,
                    label: "Mine"
                ),
            ]
        )
        let swapped = KeybindingCatalog.renameLenses(
            in: [layer],
            ["Writing": "Reading", "Reading": "Writing"]
        )
        let rows = swapped[0].bindings
        #expect(rows.map(\.lua) == [reading.lua, writing.lua])
        #expect(rows.map(\.label) == [reading.label, "Mine"])
    }
}
