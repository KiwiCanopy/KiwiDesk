import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// `list_windows` per layout (#2492): a floating-mode Space judges
/// its members as floats, a scrolling cut names its side, a bsp pile
/// reads its covered member's top band, a monocle park reports no
/// frame, a full-screen window no verdict — and the keys it shares
/// with `explain_window` answer alike.
@Suite("list_windows layouts", .serialized)
@MainActor
struct ListWindowsLayoutTests {
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
                    "kiwidesk-list-layouts-\(UUID().uuidString)"
                )
        )
        core.tiler.visibleBounds = { _ in Self.bounds }
        core.execute("set_mode", args: [.string("1"), .string(mode)])
        for window in windows {
            core.state.apply(.windowCreated(window))
        }
        return core
    }

    private func window(
        _ id: UInt32,
        frame: CGRect = CGRect(x: 40, y: 40, width: 300, height: 200),
        fullscreen: Bool = false
    ) -> ManagedWindow {
        ManagedWindow(
            id: WindowID(id),
            pid: Int32(930_000 + id),
            appName: "App\(id)",
            frame: frame,
            isFullscreen: fullscreen
        )
    }

    private func entries(
        _ core: KiwiCore
    ) throws -> [UInt32: [String: JSONValue]] {
        let response = core.execute("list_windows")
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

    @Test("Floating mode: every member is a visible float")
    func floatingModeMembersAreFloats() throws {
        let frame = CGRect(x: 600, y: 300, width: 200, height: 150)
        let core = makeCore(
            mode: "floating",
            windows: [window(1), window(2, frame: frame)]
        )
        core.state.apply(.windowFocused(WindowID(1)))
        let seen = try entries(core)
        for id: UInt32 in [1, 2] {
            #expect(seen[id]?["floats"] == .bool(true))
            #expect(seen[id]?["visibility"] == .string("visible"))
        }
        #expect(seen[2]?["frame"] == KiwiCore.json(rect: frame))
    }

    @Test("Scrolling: a column past the edge names its side")
    func scrollingCutNamesTheSide() throws {
        let core = makeCore(
            mode: "scrolling",
            windows: [window(1), window(2), window(3)]
        )
        core.execute("scroll.set_slot_size", args: [.number(700)])
        core.state.apply(.windowFocused(WindowID(1)))
        let seen = try entries(core)
        #expect(seen[1]?["visibility"] == .string("visible"))
        #expect(seen[2]?["visibility"] == .string("partly_left"))
    }

    /// Not even one minimum-size window fits, so bsp piles them,
    /// the second 40 pt lower (two that only miss side by side
    /// scroll instead, #2542). Focused, the lower one is in front
    /// and covers the upper one but for its top band, so the
    /// coverage judgement reads that band, not the whole window.
    @Test("A pile's covered member reads only its top band")
    func pileCoveredMember() throws {
        let core = makeCore(mode: "bsp", windows: [window(1), window(2)])
        core.execute("set_min_window_size", args: [.number(1100)])
        core.state.apply(.windowFocused(WindowID(2)))
        let seen = try entries(core)
        #expect(seen[1]?["visibility"] == .string("partly_top"))
        #expect(seen[1]?["shown"] == .bool(true))
    }

    @Test("A monocle park reports no frame")
    func monocleParkHasNoFrame() throws {
        let core = makeCore(
            mode: "monocle",
            windows: [window(1), window(2)]
        )
        // The park check measures against the topology seam,
        // which the factory pins to no screens.
        core.tiler.allScreenBounds = { [Self.bounds] }
        core.execute("monocle.set_hide_style", args: [.string("park")])
        core.state.apply(.windowFocused(WindowID(1)))
        let seen = try entries(core)
        #expect(seen[2]?["visibility"] == .string("hidden"))
        #expect(seen[2]?["frame"] == .null)
        #expect(seen[1]?["frame"] != .null)
    }

    @Test("A full-screen window takes no verdict")
    func fullscreenHasNoVerdict() throws {
        let core = makeCore(
            mode: "stack",
            windows: [window(1), window(2, fullscreen: true)]
        )
        let entry = try #require(try entries(core)[2])
        #expect(entry["fullscreen"] == .bool(true))
        #expect(entry["visibility"] == .null)
    }

    /// Scripts join the two answers, so a key they share must
    /// answer alike for one window.
    @Test("Keys shared with explain_window answer alike")
    func explainParity() throws {
        let core = makeCore(mode: "stack", windows: [window(1), window(2)])
        core.state.apply(.windowFocused(WindowID(2)))
        let listed = try entries(core)
        for id: UInt32 in [1, 2] {
            let explained = core.execute(
                "explain_window",
                args: [.number(Double(id))]
            )
            guard case .object(let explain)? = explained.data,
                case .object(let float)? = explain["float"]
            else {
                Issue.record("explain_window answered \(explained)")
                continue
            }
            for key in ["id", "space_id", "focused", "fullscreen"] {
                #expect(listed[id]?[key] == explain[key], "\(key)")
            }
            #expect(listed[id]?["floats"] == float["floats"])
        }
    }

    /// A tiled sticky window homed on a Stack Space and drawn on a
    /// floating-mode one floats where it draws, in both verbs.
    @Test("A sticky traveler floats where it draws, in both verbs")
    func travelerParity() throws {
        let core = makeCore(mode: "stack", windows: [window(1)])
        core.state.workspaces.ensureSpace("2")
        core.execute("set_mode", args: [.string("2"), .string("floating")])
        var traveler = window(3)
        traveler.stickyScope = .global
        core.state.apply(.windowCreated(traveler))
        core.state.workspaces.add(WindowID(3), to: "1")
        core.state.workspaces.activate("2")
        let listed = try #require(try entries(core)[3])
        #expect(listed["floats"] == .bool(true))
        let explained = core.execute("explain_window", args: [.number(3)])
        guard case .object(let explain)? = explained.data,
            case .object(let float)? = explain["float"]
        else {
            Issue.record("explain_window answered \(explained)")
            return
        }
        #expect(float["floats"] == listed["floats"])
    }
}
