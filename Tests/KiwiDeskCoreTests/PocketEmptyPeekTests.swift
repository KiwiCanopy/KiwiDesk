import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// An empty Pocket explains itself (#2941 ▸ Ruling): its peek holds
/// how a window goes in, each chord live from the GUI's one hook and
/// a line only while its key is bound, then the two Settings rows.
@Suite("An empty Pocket's click explains it (#2941)", .serialized)
@MainActor
struct PocketEmptyPeekTests {
    private let window = WindowID(1)

    private func core() -> KiwiCore {
        let core = makeTestCore()
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: window,
                    pid: 900_001,
                    appName: "Other",
                    frame: CGRect(x: 100, y: 100, width: 600, height: 400)
                )
            )
        )
        core.state.apply(.windowFocused(window))
        core.execute("pocket.set_capacity", args: [.string("several")])
        return core
    }

    private func bind(_ core: KiwiCore, toggle: Bool = true) {
        core.barMenuHooks.pocketVerbChord = { verb in
            switch verb {
            case .pocket:
                RenderedChord(drawn: "⌃⌥P", spoken: "Control Option P")
            case .togglePocketWindow:
                toggle
                    ? RenderedChord(
                        drawn: "⌃⌥⇧P",
                        spoken: "Control Option Shift P"
                    ) : nil
            }
        }
    }

    private func empty(_ core: KiwiCore) throws -> BarPeekContent.Empty {
        try #require(core.barPeekContent(.pocket([]), on: nil)?.empty)
    }

    @Test("both keys bound: two lines, each chord drawn and spoken")
    func bothKeysLine() throws {
        LocalizationManager.shared.select("en")
        let core = core()
        bind(core)
        let state = try empty(core)
        #expect(state.title == "Your Pocket is empty")
        #expect(
            state.lines.map(\.drawn) == [
                "Drag a window here, or press ⌃⌥P to pocket the focused "
                    + "window right away.",
                "Press ⌃⌥⇧P to turn Pocket on or off for the focused "
                    + "window.",
            ]
        )
        let spoken = state.lines.map(\.spoken)
        #expect(spoken.first?.contains("Control Option P") == true)
        #expect(spoken.last?.contains("Control Option Shift P") == true)
        #expect(state.rows.map(\.landing) == [.pocketShortcuts, .pocketKeys])
        #expect(state.spoken.hasPrefix("Your Pocket is empty\n"))
    }

    /// `pocket` puts the out window back before it marks the focus,
    /// so the line says that (#2941 ▸ 2).
    @Test("a pocket window out: the first line puts it back")
    func outWindowPutsBack() throws {
        LocalizationManager.shared.select("en")
        let core = core()
        bind(core)
        core.execute("toggle_pocket_window")
        core.execute("pocket")
        core.execute("pocket")
        #expect(core.state.pocketPutBackNext(focused: window) == window)
        let state = try empty(core)
        #expect(
            state.lines.first?.drawn
                == "Drag a window here, or press ⌃⌥P to put back the "
                + "one you used last."
        )
    }

    @Test("no key bound: the drag line points at Settings, alone")
    func unboundPointsAtSettings() throws {
        LocalizationManager.shared.select("en")
        let core = core()
        let state = try empty(core)
        #expect(
            state.lines.map(\.drawn) == [
                "Drag a window here to pocket it, or set a shortcut "
                    + "for Pocket or take out in Settings."
            ]
        )
        bind(core, toggle: false)
        #expect(try empty(core).lines.count == 1)
    }

    @Test("an empty list of another source shows nothing")
    func otherSourcesStayEmpty() {
        let core = core()
        #expect(core.barPeekContent(.glyph([]), on: nil) == nil)
        #expect(core.barPeekContent(.run([]), on: nil) == nil)
    }

    @Test("the body draws the rows as landing buttons that speak")
    func bodyRowsLand() throws {
        LocalizationManager.shared.select("en")
        let core = core()
        bind(core)
        let content = BarPeekContent(empty: try empty(core))
        let body = BarPeekBody()
        var landed: [SettingsLanding] = []
        body.onLand = { landed.append($0) }
        let size = body.build(content, shelf: KiwiShelf(), maxHeight: 10)
        #expect(size.height > 10)
        #expect(
            body.targets.map(\.action) == [
                .landing(.pocketShortcuts), .landing(.pocketKeys),
            ]
        )
        let first = try #require(body.targets.first)
        let point = CGPoint(x: first.frame.midX, y: first.frame.midY)
        body.press(at: point)
        body.release(at: point)
        #expect(landed == [.pocketShortcuts])
        let info = try #require(body.emptyInfo)
        #expect(info.isAccessibilityElement())
        #expect(info.accessibilityLabel() == content.empty?.spoken)
        let rows = body.labels.compactMap { $0 as? BarPeekPressLabel }
        #expect(rows.count == 2)
        #expect(rows.allSatisfy { $0.accessibilityRole() == .button })
        #expect(rows.last?.accessibilityPerformPress() == true)
        #expect(landed == [.pocketShortcuts, .pocketKeys])
        #expect(body.rules.count == 1)
    }
}
