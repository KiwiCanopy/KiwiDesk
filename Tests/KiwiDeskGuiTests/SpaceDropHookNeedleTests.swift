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

    @Test("every end of a hold owes its shortcuts first")
    func heldEndsOwe() throws {
        let door = try SourceScan.functionBody(
            of: "endHold",
            in: "KiwiCore+HeldSpaces.swift",
            under: "Profiles"
        )
        #expect(door.contains("oweShortcutDrop(id)"))
        // The go-home arm clears every hold up front, so it owes
        // by hand; the emptied retire takes the door.
        let arms = [
            "refileHeldSpaces": "oweShortcutDrop(id)",
            "retireEmptiedHeldSpaces": "endHold(of: id)",
        ]
        for (function, owe) in arms {
            let body = try SourceScan.functionBody(
                of: function,
                in: "KiwiCore+HeldSpaces.swift",
                under: "Profiles"
            )
            let owed = try #require(
                body.range(of: owe),
                "\(function) never owes"
            )
            let forward = try #require(
                body.range(of: "forwardWindows(of: id")
            )
            #expect(owed.lowerBound < forward.lowerBound)
        }
    }

    @Test("stop pays the debt before its capture")
    func stopPays() throws {
        let body = try SourceScan.functionBody(
            of: "stop",
            in: "KiwiCore+Lifecycle.swift",
            under: "App"
        )
        let pay = try #require(body.range(of: "payOwedShortcutDrops()"))
        let capture = try #require(body.range(of: "stopCapture("))
        #expect(pay.lowerBound < capture.lowerBound)
    }

    @Test("the app hands a drop to an open draft")
    func appWiresTheDrop() throws {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/AppDelegate.swift")
        let source = try SourceScan.strippedSource(at: url)
            .split(whereSeparator: \.isWhitespace).joined()
        #expect(
            source.contains(
                "core.onShortcutsDropped={[weakself]spacesin"
                    + "self?.dashboardIfCreated?.adoptShortcutDrop(spaces)"
            )
        )
    }
}
