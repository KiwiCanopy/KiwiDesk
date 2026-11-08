import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

private let bounds = CGRect(x: 0, y: 25, width: 1600, height: 1000)
private let space = SpaceID("1")
private let w1 = WindowID(1)
private let w2 = WindowID(2)
private let w3 = WindowID(3)

/// A Monocle Space of three tiled windows, `w1` focused, gaps set,
/// the Space Bar always shown and reserving.
@MainActor
private func makeCore(
    maximize: Bool,
    hideStyle: MonocleParams.HideStyle = .stack
) -> KiwiCore {
    let core = makeTestCore()
    core.tiler.visibleBounds = { _ in bounds }
    core.tiler.settings.gapsGlobal = Gaps(
        outer: .init(top: 12, bottom: 12, left: 12, right: 12),
        inner: .init(horizontal: 8, vertical: 8)
    )
    core.tiler.settings.spaceBarStyle.visibility = .always
    core.tiler.settings.monocle.hideStyle = hideStyle
    for id in [w1, w2, w3] {
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: id, pid: 900_001, appName: "A")
            )
        )
    }
    core.execute("set_mode", args: [.string("1"), .string("monocle")])
    core.state.workspaces.focus(w1, in: space)
    core.execute(
        "monocle.set_maximize_windows",
        args: [.bool(maximize)]
    )
    return core
}

/// Monocle's "Maximize windows" (#2976): every member's frame is
/// settled in the layout input — the whole visible frame, gaps 0 —
/// and `Space.maximized` is never written.
@Suite("Monocle maximize windows: layout (#2976)", .serialized)
@MainActor
struct MonocleMaximizeLayoutTests {
    @Test("Every member fills the visible frame with no gaps")
    func everyMemberFills() {
        let core = makeCore(maximize: true)
        let frames = core.tiler.placedFrames(state: core.state)
        for id in [w1, w2, w3] {
            #expect(frames[id] == bounds)
        }
        #expect(core.state.workspaces[space]?.maximized == nil)
    }

    @Test("Off keeps the gaps and the Space Bar's strip")
    func offKeepsTheInsets() {
        let core = makeCore(maximize: false)
        let frame = core.tiler.placedFrames(state: core.state)[w1]
        #expect(frame != nil)
        #expect(frame != bounds)
        #expect(bounds.contains(frame ?? .zero))
    }

    @Test("A parked member parks its full frame")
    func parkedMemberHoldsTheFullFrame() throws {
        let core = makeCore(maximize: true, hideStyle: .park)
        let frames = core.tiler.placedFrames(state: core.state)
        #expect(frames[w1] == bounds)
        let parked = try #require(frames[w2])
        #expect(parked.size == bounds.size)
        #expect(parked != bounds)
    }

    @Test("Another layout is untouched by the setting")
    func otherLayoutsUntouched() throws {
        let core = makeCore(maximize: true)
        core.execute("set_mode", args: [.string("1"), .string("bsp")])
        let frame = core.tiler.placedFrames(state: core.state)[w1]
        #expect(frame != bounds)
        #expect(
            core.tiler.settings.layoutGaps(
                for: try #require(core.state.workspaces[space])
            ) == core.tiler.settings.gapsGlobal
        )
    }

    @Test("The setter takes a boolean and refuses anything else")
    func setterParses() {
        let core = makeCore(maximize: false)
        #expect(
            core.execute(
                "monocle.set_maximize_windows",
                args: [.bool(true)]
            ).isSuccess
        )
        #expect(core.tiler.settings.monocle.maximizeWindows)
        #expect(
            !core.execute(
                "monocle.set_maximize_windows",
                args: [.string("yes")]
            ).isSuccess
        )
        #expect(core.tiler.settings.monocle.maximizeWindows)
    }

    @Test("The leaf is stored as maximize_windows; absent reads off")
    func leafRoundTrips() throws {
        var params = MonocleParams()
        params.maximizeWindows = true
        let data = try JSONEncoder().encode(params)
        let object = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        #expect(object["maximize_windows"] as? Bool == true)
        let decoded = try JSONDecoder().decode(
            MonocleParams.self,
            from: data
        )
        #expect(decoded.maximizeWindows)
        let older = try JSONDecoder().decode(
            MonocleParams.self,
            from: Data(#"{"orientation":"horizontal"}"#.utf8)
        )
        #expect(!older.maximizeWindows)
    }
}
