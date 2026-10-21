import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// `list_windows` (#2492): where each tracked window sits, from the
/// frames KiwiDesk sent, through the visibility verdict the App Bar
/// reads — and a window on a Space no screen shows reports no frame,
/// never its parked corner.
@Suite("list_windows", .serialized)
@MainActor
struct ListWindowsTests {
    private static let bounds = CGRect(
        x: 0,
        y: 0,
        width: 1000,
        height: 800
    )

    private func makeCore(
        mode: String,
        windows: [ManagedWindow]
    ) -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent(
                    "kiwidesk-list-windows-\(UUID().uuidString)"
                )
        )
        core.tiler.visibleBounds = { _ in Self.bounds }
        core.execute("set_mode", args: [.string("1"), .string(mode)])
        for window in windows {
            core.state.apply(.windowCreated(window))
        }
        return core
    }

    private func window(_ id: UInt32, floating: Bool = false)
        -> ManagedWindow
    {
        ManagedWindow(
            id: WindowID(id),
            pid: Int32(910_000 + id),
            appName: "App\(id)",
            frame: CGRect(x: 40, y: 40, width: 300, height: 200),
            isFloating: floating
        )
    }

    /// The answer's entries, keyed by window id.
    private func entries(
        _ core: KiwiCore,
        _ args: [JSONValue] = []
    ) throws -> [UInt32: [String: JSONValue]] {
        let response = core.execute("list_windows", args: args)
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

    private func hasRect(_ value: JSONValue?) -> Bool {
        guard case .object(let rect)? = value else { return false }
        return rect["width"]?.numberValue != nil
    }

    @Test("Stack: every tile is shown and visible, with a frame")
    func stackTilesAreVisible() throws {
        let core = makeCore(mode: "stack", windows: [window(1), window(2)])
        core.state.apply(.windowFocused(WindowID(1)))
        let seen = try entries(core)
        for id: UInt32 in [1, 2] {
            let entry = try #require(seen[id])
            #expect(entry["shown"] == .bool(true))
            #expect(entry["visibility"] == .string("visible"))
            #expect(hasRect(entry["frame"]))
            #expect(entry["space_id"] == .string("1"))
            #expect(entry["floats"] == .bool(false))
        }
        #expect(seen[1]?["focused"] == .bool(true))
        #expect(seen[2]?["focused"] == .bool(false))
    }

    @Test("Monocle: the back member reads hidden")
    func monocleBackIsHidden() throws {
        let core = makeCore(
            mode: "monocle",
            windows: [window(1), window(2)]
        )
        core.state.apply(.windowFocused(WindowID(1)))
        let seen = try entries(core)
        #expect(seen[1]?["visibility"] == .string("visible"))
        #expect(seen[2]?["visibility"] == .string("hidden"))
        #expect(seen[2]?["shown"] == .bool(true))
    }

    @Test("A float reports its own frame and floats")
    func floatReportsItsFrame() throws {
        let core = makeCore(
            mode: "stack",
            windows: [window(1), window(2, floating: true)]
        )
        core.state.apply(.windowFocused(WindowID(1)))
        let entry = try #require(try entries(core)[2])
        #expect(entry["floats"] == .bool(true))
        #expect(entry["shown"] == .bool(true))
        #expect(
            entry["frame"]
                == KiwiCore.json(
                    rect: CGRect(x: 40, y: 40, width: 300, height: 200)
                )
        )
    }

    /// A Space no screen shows sits parked, so its frame is the
    /// corner, never where the window lives.
    @Test("A window on an unshown Space has no frame")
    func unshownSpaceHasNoFrame() throws {
        let core = makeCore(mode: "stack", windows: [window(1)])
        core.state.workspaces.ensureSpace("2")
        core.state.apply(.windowCreated(window(3)))
        core.state.workspaces.add(WindowID(3), to: "2")
        let entry = try #require(try entries(core)[3])
        #expect(entry["space_id"] == .string("2"))
        #expect(entry["shown"] == .bool(false))
        #expect(entry["frame"] == .null)
        #expect(entry["visibility"] == .null)
    }

    @Test("A Space filter lists that Space's windows alone")
    func spaceFilter() throws {
        let core = makeCore(mode: "stack", windows: [window(1)])
        core.state.workspaces.ensureSpace("2")
        core.state.apply(.windowCreated(window(3)))
        core.state.workspaces.add(WindowID(3), to: "2")
        #expect(Set(try entries(core, [.number(2)]).keys) == [3])
        #expect(Set(try entries(core, [.string("1")]).keys) == [1])
        #expect(Set(try entries(core).keys) == [1, 3])
        let refused = core.execute("list_windows", args: [.string("9")])
        #expect(!refused.isSuccess)
    }
}
