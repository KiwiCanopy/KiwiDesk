import Testing

@testable import KiwiDeskCore

/// `Space.runHeads` and `runTails` bookkeeping (#2235): a removed
/// head hands its place to its successor and a removed tail to its
/// predecessor, so the run keeps resting where it was, and a mode
/// write forgets every end.
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

    @Test("A removed tail hands its place to its predecessor")
    func tailRemovalHandsBack() {
        var space = Space(id: "1", mode: .stack, windows: ids)
        space.runTails = [ids[2]]
        space.remove(ids[2])
        #expect(space.runTails == [ids[1]])
    }

    @Test("The first window removed as tail leaves no tail")
    func firstTailLeavesNone() {
        var space = Space(id: "1", mode: .stack, windows: ids)
        space.runTails = [ids[0]]
        space.remove(ids[0])
        #expect(space.runTails.isEmpty)
    }

    @Test("A mode write forgets every head and tail")
    func modeWriteClears() {
        var manager = WorkspaceManager()
        manager.ensureSpace("1", mode: .stack)
        manager.withSpace("1") {
            $0.runHeads = [WindowID(9)]
            $0.runTails = [WindowID(9)]
        }
        manager.setMode("1", .track)
        #expect(manager["1"]?.runHeads.isEmpty == true)
        #expect(manager["1"]?.runTails.isEmpty == true)
    }
}
