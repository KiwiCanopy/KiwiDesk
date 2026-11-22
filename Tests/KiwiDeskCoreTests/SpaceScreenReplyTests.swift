import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// `get_state` places every Space on its screen and says which ones
/// are shown, and `list_monitors` names the Space each screen shows
/// (#3549): one query lets a bar draw each screen's Spaces, empty
/// ones included. The two replies read the same state, so "Space X
/// shown on D" holds exactly when monitor D's `space_id` is X.
@Suite("get_state and list_monitors place Spaces", .serialized)
@MainActor
struct SpaceScreenReplyTests {
    private let main = DisplayID(900_001)
    private let side = DisplayID(900_002)

    private func makeCore() -> KiwiCore {
        makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent(
                    "kiwidesk-space-screens-\(UUID().uuidString)"
                )
        )
    }

    /// Space 1 active on the main screen; Spaces 2 (empty, shown)
    /// and 3 (not shown) on the side screen.
    private func twoScreenCore() -> KiwiCore {
        let core = makeCore()
        let frame = CGRect(x: 0, y: 0, width: 1000, height: 800)
        core.state.apply(
            .displaysChanged([
                Display(id: main, name: "Main", frame: frame),
                Display(
                    id: side,
                    name: "Side",
                    frame: frame.offsetBy(dx: 1000, dy: 0)
                ),
            ])
        )
        core.state.workspaces.assign("1", to: main)
        core.state.workspaces.assign("2", to: side)
        core.state.workspaces.assign("3", to: side)
        core.state.workspaces.activate("1")
        core.state.workspaces.show("2", on: side)
        return core
    }

    private func spaces(_ core: KiwiCore) -> [String: [String: JSONValue]] {
        guard case .object(let root)? = core.execute("get_state").data,
            case .array(let list)? = root["spaces"]
        else {
            Issue.record("get_state carried no spaces")
            return [:]
        }
        var byID: [String: [String: JSONValue]] = [:]
        for case .object(let space) in list {
            if let id = space["id"]?.stringValue { byID[id] = space }
        }
        return byID
    }

    private func monitors(_ core: KiwiCore) -> [UInt32: JSONValue] {
        guard case .array(let list)? = core.execute("list_monitors").data
        else {
            Issue.record("list_monitors answered no array")
            return [:]
        }
        var byID: [UInt32: JSONValue] = [:]
        for case .object(let monitor) in list {
            if let id = monitor["id"]?.numberValue {
                byID[UInt32(id)] = monitor["space_id"] ?? .null
            }
        }
        return byID
    }

    @Test("An empty Space shown on a second screen is placed there")
    func emptySpaceOnSecondScreen() {
        let core = twoScreenCore()
        let byID = spaces(core)
        #expect(byID["2"]?["display"]?.numberValue == Double(side.raw))
        #expect(byID["2"]?["shown"]?.boolValue == true)
        #expect(byID["3"]?["display"]?.numberValue == Double(side.raw))
        #expect(byID["3"]?["shown"]?.boolValue == false)
        #expect(byID["1"]?["display"]?.numberValue == Double(main.raw))
        #expect(byID["1"]?["shown"]?.boolValue == true)
        let shown = monitors(core)
        #expect(shown[side.raw]?.stringValue == "2")
        #expect(shown[main.raw]?.stringValue == "1")
    }

    @Test("With no screen the active Space is shown on none")
    func noScreens() throws {
        let core = makeCore()
        core.state.apply(.displaysChanged([]))
        let active = try #require(core.state.workspaces.activeSpace)
        let space = spaces(core)[active.raw]
        #expect(space?["display"] == .null)
        #expect(space?["shown"]?.boolValue == true)
        #expect(monitors(core).isEmpty)
    }

    @Test("A shown Space and its screen's space_id name each other")
    func joinHoldsBothWays() {
        let core = twoScreenCore()
        let byID = spaces(core)
        let shown = monitors(core)
        for (id, space) in byID {
            guard space["shown"]?.boolValue == true,
                let display = space["display"]?.numberValue
            else { continue }
            #expect(shown[UInt32(display)]?.stringValue == id)
        }
        for (display, spaceID) in shown {
            guard let id = spaceID.stringValue else { continue }
            #expect(byID[id]?["shown"]?.boolValue == true)
            #expect(
                byID[id]?["display"]?.numberValue == Double(display)
            )
        }
        #expect(shown.count == 2)
    }

    @Test("A Space's shown agrees with list_windows' shown")
    func agreesWithListWindows() {
        let core = twoScreenCore()
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1000, height: 800)
        }
        for (id, space): (UInt32, SpaceID) in [(1, "2"), (2, "3")] {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(id),
                        pid: Int32(900_100 + id),
                        appName: "App\(id)",
                        frame: CGRect(x: 40, y: 40, width: 300, height: 200),
                        isFloating: true
                    )
                )
            )
            core.state.workspaces.add(WindowID(id), to: space)
        }
        guard case .array(let list)? = core.execute("list_windows").data
        else {
            Issue.record("list_windows answered no array")
            return
        }
        let byID = spaces(core)
        var checked = 0
        for case .object(let window) in list {
            guard let space = window["space_id"]?.stringValue else {
                continue
            }
            #expect(window["shown"] == byID[space]?["shown"])
            checked += 1
        }
        #expect(checked == 2)
    }
}
