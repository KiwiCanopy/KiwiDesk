import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// `list_windows`' `z` (#2546): each on-screen window's rank among
/// the tracked windows on its screen, read from the WindowServer's
/// front-to-back list through the `frontStack` seam, 0 frontmost —
/// and the `app`, `pid` and `index` fields beside it.
@Suite("list_windows stacking", .serialized)
@MainActor
struct ListWindowsStackingTests {
    private static let bounds = CGRect(
        x: 0,
        y: 0,
        width: 1000,
        height: 800
    )
    private let main = DisplayID(1)
    private let side = DisplayID(2)

    /// Space 1 on the main screen holds tiles 1 and 2 and float 4;
    /// Space 2, shown on the side screen, holds 3; Space 3, which
    /// no screen shows, holds 5.
    private func makeCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent(
                    "kiwidesk-list-stacking-\(UUID().uuidString)"
                )
        )
        core.tiler.visibleBounds = { _ in Self.bounds }
        core.frontStack = { [] }
        core.execute("set_mode", args: [.string("1"), .string("stack")])
        for (id, frame) in [
            (main, Self.bounds),
            (side, Self.bounds.offsetBy(dx: 1000, dy: 0)),
        ] {
            core.state.workspaces.upsertDisplay(
                Display(id: id, name: "Screen \(id.raw)", frame: frame)
            )
        }
        core.state.workspaces.assign("1", to: main)
        core.state.workspaces.assign("2", to: side)
        core.state.workspaces.assign("3", to: side)
        core.state.workspaces.activate("1")
        core.state.workspaces.show("2", on: side)
        for id: UInt32 in [1, 2, 4] {
            core.state.apply(.windowCreated(window(id, floating: id == 4)))
        }
        for (id, space): (UInt32, SpaceID) in [(3, "2"), (5, "3")] {
            core.state.apply(.windowCreated(window(id, floating: true)))
            core.state.workspaces.add(WindowID(id), to: space)
        }
        core.state.apply(.windowFocused(WindowID(1)))
        return core
    }

    private func window(_ id: UInt32, floating: Bool = false)
        -> ManagedWindow
    {
        ManagedWindow(
            id: WindowID(id),
            pid: Int32(920_000 + id),
            appName: "App\(id)",
            frame: CGRect(x: 40, y: 40, width: 300, height: 200),
            isFloating: floating
        )
    }

    private func listed(_ numbers: [UInt32])
        -> [KiwiCore.FrontWindow]
    {
        numbers.map {
            KiwiCore.FrontWindow(
                number: $0,
                pid: 1,
                layer: 0,
                frame: Self.bounds
            )
        }
    }

    /// The answer's entries, keyed by window id.
    private func entries(
        _ core: KiwiCore
    ) throws -> [UInt32: [String: JSONValue]] {
        let response = core.execute("list_windows", args: [])
        guard case .array(let list)? = response.data else {
            Issue.record("list_windows answered \(response)")
            return [:]
        }
        var byID: [UInt32: [String: JSONValue]] = [:]
        for entry in list {
            guard case .object(let object) = entry else { continue }
            let id = try #require(object["id"]?.numberValue)
            byID[UInt32(id)] = object
        }
        return byID
    }

    @Test("z counts per screen, front to back, among tracked windows")
    func ranksPerScreen() throws {
        let core = makeCore()
        // 99 is no tracked window: it covers, and is never counted.
        core.frontStack = { self.listed([99, 2, 3, 4, 1]) }
        let seen = try entries(core)
        #expect(seen[2]?["z"] == .number(0))
        #expect(seen[4]?["z"] == .number(1))
        #expect(seen[1]?["z"] == .number(2))
        #expect(seen[3]?["z"] == .number(0))
    }

    /// A sticky window of Space 3 draws on the main screen, so it
    /// ranks there whichever Space the call lists.
    @Test("A Space filter leaves every rank as it was")
    func filterKeepsRanks() throws {
        let core = makeCore()
        var traveler = window(6, floating: true)
        traveler.stickyScope = .global
        core.state.apply(.windowCreated(traveler))
        core.state.workspaces.add(WindowID(6), to: "3")
        core.frontStack = { self.listed([6, 4, 1, 2]) }
        let all = try entries(core)
        #expect(all[6]?["z"] == .number(0))
        #expect(all[4]?["z"] == .number(1))
        let response = core.execute("list_windows", args: [.string("1")])
        guard case .array(let list)? = response.data else {
            Issue.record("list_windows answered \(response)")
            return
        }
        for case .object(let entry) in list {
            let id = try #require(entry["id"]?.numberValue)
            #expect(entry["z"] == all[UInt32(id)]?["z"])
        }
        #expect(list.count == 3)
    }

    /// A Space no screen shows sits parked, and a parked window is
    /// on screen to the WindowServer — at its corner.
    @Test("A window no screen shows has no z, though listed")
    func unshownHasNoRank() throws {
        let core = makeCore()
        core.frontStack = { self.listed([5, 3, 1, 2]) }
        let seen = try entries(core)
        #expect(seen[5]?["z"] == .null)
        #expect(seen[3]?["z"] == .number(0))
        #expect(seen[1]?["z"] == .number(0))
        #expect(seen[2]?["z"] == .number(1))
    }

    /// A monocle's back member is parked behind the front one, on
    /// screen to the WindowServer all the same.
    @Test("A monocle park has no z")
    func monocleParkHasNoRank() throws {
        let core = makeCore()
        core.execute(
            "set_mode",
            args: [.string("1"), .string("monocle")]
        )
        // The park check measures against the topology seam,
        // which the factory pins to no screens.
        core.tiler.allScreenBounds = { [Self.bounds] }
        core.execute("monocle.set_hide_style", args: [.string("park")])
        core.state.apply(.windowFocused(WindowID(1)))
        core.frontStack = { self.listed([2, 1, 4]) }
        let seen = try entries(core)
        #expect(seen[2]?["frame"] == .null)
        #expect(seen[2]?["z"] == .null)
        #expect(seen[1]?["z"] == .number(0))
    }

    @Test("A window listed twice takes one rank")
    func duplicateTakesOneRank() throws {
        let core = makeCore()
        core.frontStack = { self.listed([2, 2, 1]) }
        let seen = try entries(core)
        #expect(seen[2]?["z"] == .number(0))
        #expect(seen[1]?["z"] == .number(1))
    }

    @Test("A window the WindowServer does not list has no z")
    func unlistedHasNoRank() throws {
        let core = makeCore()
        core.frontStack = { self.listed([2]) }
        let seen = try entries(core)
        #expect(seen[2]?["z"] == .number(0))
        #expect(seen[1]?["z"] == .null)
        #expect(seen[3]?["z"] == .null)
    }

    /// Without a tracked window on screen there is nothing to rank,
    /// so the WindowServer is not asked.
    @Test("No window on screen reads nothing")
    func nothingOnScreenSkipsTheRead() throws {
        let core = makeCore()
        for id: UInt32 in [1, 2, 3, 4] {
            core.state.workspaces.add(WindowID(id), to: "3")
        }
        var reads = 0
        core.frontStack = {
            reads += 1
            return []
        }
        _ = try entries(core)
        #expect(reads == 0)
    }

    @Test("app, pid and index: the window's place in its Space's row")
    func appPidAndIndex() throws {
        let core = makeCore()
        let seen = try entries(core)
        #expect(seen[1]?["app"] == .string("App1"))
        #expect(seen[1]?["pid"] == .number(920_001))
        let row = try #require(core.state.workspaces["1"]?.windows)
        #expect(row.count == 3)
        for (offset, id) in row.enumerated() {
            #expect(seen[id.raw]?["index"] == .number(Double(offset + 1)))
        }
        #expect(seen[3]?["index"] == .number(1))
    }

    @Test("A window no Space holds has no index")
    func unfiledHasNoIndex() throws {
        let core = makeCore()
        core.state.workspaces.remove(WindowID(2))
        let entry = try #require(try entries(core)[2])
        #expect(entry["space_id"] == .null)
        #expect(entry["index"] == .null)
    }
}
