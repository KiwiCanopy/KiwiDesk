import Testing

@testable import KiwiDeskCore

/// `Space.runHeads` bookkeeping (#2235): a removed head hands its
/// place to its successor so the run keeps resting where it was,
/// and a mode write forgets every head.
@Suite("Space run heads")
struct SpaceRunHeadsTests {
    private let ids = (1...4).map { WindowID(UInt32($0)) }

    @Test("A removed head hands its place to its successor")
    func removalHandsOn() {
        var space = Space(id: "1", mode: .stack, windows: ids)
        space.runHeads = [ids[1]]
        space.remove(ids[1])
        #expect(space.runHeads == [ids[2]])
    }

    @Test("The last window removed as head leaves no head")
    func lastHeadLeavesNone() {
        var space = Space(id: "1", mode: .stack, windows: ids)
        space.runHeads = [ids[3]]
        space.remove(ids[3])
        #expect(space.runHeads.isEmpty)
    }

    @Test("Removing a window that is no head keeps the heads")
    func otherRemovalKeeps() {
        var space = Space(id: "1", mode: .stack, windows: ids)
        space.runHeads = [ids[2]]
        space.remove(ids[0])
        #expect(space.runHeads == [ids[2]])
    }

    @Test("A mode write forgets every head")
    func modeWriteClears() {
        var manager = WorkspaceManager()
        manager.ensureSpace("1", mode: .stack)
        manager.withSpace("1") { $0.runHeads = [WindowID(9)] }
        manager.setMode("1", .track)
        #expect(manager["1"]?.runHeads.isEmpty == true)
    }
}
