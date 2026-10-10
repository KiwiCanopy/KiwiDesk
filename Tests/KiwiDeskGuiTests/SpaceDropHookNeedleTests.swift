import Foundation
import Testing

/// What the one Space drop and the held renumber owe (#1655,
/// #1827): the drop forgets the Space's history and owes a
/// temporary or held Space's shortcuts; the held go-home arms that
/// clear the hold before forwarding owe the shortcuts by hand; the
/// renumber carries the history to the new number.
@Suite("Space drop hooks (#1655, #1827)")
struct SpaceDropHookNeedleTests {
    @Test("the one Space drop forgets and owes")
    func dropForgetsAndOwes() throws {
        let body = try SourceScan.functionBody(
            of: "forwardWindows",
            in: "KiwiCore+ProfileSpaces.swift",
            under: "Profiles"
        )
        #expect(body.contains("spaceHistory.trails.forget(space)"))
        #expect(body.contains("oweShortcutDropIfLiveOnly(space)"))
    }

    @Test("a held renumber carries the history")
    func renumberRekeys() throws {
        let body = try SourceScan.functionBody(
            of: "moveMembers",
            in: "KiwiCore+HeldSpaces.swift",
            under: "Profiles"
        )
        #expect(body.contains("spaceHistory.trails.rekey("))
    }

    @Test("both held arms that end a hold first owe its shortcuts")
    func heldEndsOwe() throws {
        for function in ["refileHeldSpaces", "retireEmptiedHeldSpaces"] {
            let body = try SourceScan.functionBody(
                of: function,
                in: "KiwiCore+HeldSpaces.swift",
                under: "Profiles"
            )
            let owe = try #require(
                body.range(of: "oweShortcutDrop(id)"),
                "\(function) never owes"
            )
            let forward = try #require(
                body.range(of: "forwardWindows(of: id")
            )
            #expect(owe.lowerBound < forward.lowerBound)
        }
    }
}
