import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Hover focus (#1869): which window a resting pointer focuses,
/// and every stand-down. The WindowServer's front-to-back list is
/// the `frontStack` seam, stated per test; the pointer is handed
/// in, so no fixture reads the developer's hand.
@Suite("Hover focus (#1869)", .serialized)
@MainActor
struct HoverFocusTests {
    private let left = CGRect(x: 0, y: 25, width: 700, height: 875)
    private let right = CGRect(x: 740, y: 25, width: 700, height: 875)

    /// Two tiled windows side by side, w1 focused, hover on.
    private func makeCore() -> KiwiCore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("kiwidesk-hover-\(UUID().uuidString)")
        let core = makeTestCore(configDirectory: directory)
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 25, width: 1440, height: 875)
        }
        for (raw, frame) in [(UInt32(1), left), (2, right)] {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(raw),
                        pid: 10 + pid_t(raw),
                        appName: "A\(raw)",
                        frame: frame
                    )
                )
            )
        }
        core.focusWindow(WindowID(1), warp: false)
        core.tiler.settings.mouse.hoverFocus = true
        // The OS agrees w1's app is in front.
        core.frontmostPIDProvider = { 11 }
        core.frontStack = { [left, right] in
            [
                listed(number: 1, pid: 11, frame: left),
                listed(number: 2, pid: 12, frame: right),
            ]
        }
        return core
    }

    /// The pointer over w2's middle, AX space.
    private var overRight: CGPoint { CGPoint(x: 1000, y: 400) }

    private func rest(_ core: KiwiCore, at point: CGPoint) {
        // The flip is its own inverse: AX → Cocoa.
        core.focusUnderRestingPointer(
            at: GeometryUtils.axPoint(point),
            armedFocus: core.focusedWindowID
        )
    }

    private func focused(_ core: KiwiCore) -> WindowID? {
        core.activeSpace?.focused
    }

    @Test("mouse.set_hover_focus toggles and validates")
    func toggle() {
        let core = makeCore()
        core.tiler.settings.mouse.hoverFocus = false
        #expect(
            core.execute("mouse.set_hover_focus", args: [.bool(true)])
                .isSuccess
        )
        #expect(core.tiler.settings.mouse.hoverFocus)
        #expect(
            !core.execute(
                "mouse.set_hover_focus",
                args: [.string("yes")]
            ).isSuccess
        )
        #expect(core.tiler.settings.mouse.hoverFocus)
    }

    @Test("A partial mouse object keeps hover focus off")
    func partialDecode() throws {
        let decoded = try JSONDecoder().decode(
            TilingSettings.self,
            from: Data(#"{"mouse":{"follows_focus":true}}"#.utf8)
        )
        #expect(!decoded.mouse.hoverFocus)
    }

    @Test("A rest over another window focuses it")
    func restFocuses() {
        let core = makeCore()
        #expect(focused(core) == WindowID(1))
        rest(core, at: overRight)
        #expect(focused(core) == WindowID(2))
    }

    @Test("Off, nothing moves")
    func offStandsDown() {
        let core = makeCore()
        core.tiler.settings.mouse.hoverFocus = false
        rest(core, at: overRight)
        #expect(focused(core) == WindowID(1))
    }

    @Test("A held button stands it down")
    func heldButtonStandsDown() {
        let core = makeCore()
        core.mouse.pressedButtons = { 1 }
        rest(core, at: overRight)
        #expect(focused(core) == WindowID(1))
        core.mouse.pressedButtons = { 0 }
        rest(core, at: overRight)
        #expect(focused(core) == WindowID(2))
    }

    @Test("Something untracked in front stands it down")
    func untrackedInFrontStandsDown() {
        let core = makeCore()
        let menu = CGRect(x: 900, y: 300, width: 200, height: 300)
        core.frontStack = { [left, right] in
            [
                listed(number: 77, pid: 50, layer: 101, frame: menu),
                listed(number: 1, pid: 11, frame: left),
                listed(number: 2, pid: 12, frame: right),
            ]
        }
        #expect(core.hoverTarget(at: overRight) == nil)
        // Beside the menu, the window under it is reached.
        let beside = CGPoint(x: 800, y: 700)
        #expect(core.hoverTarget(at: beside)?.id == WindowID(2))
    }

    @Test("The window already focused owes nothing")
    func focusedOwesNothing() {
        let core = makeCore()
        #expect(core.hoverTarget(at: CGPoint(x: 300, y: 400)) == nil)
        #expect(core.hoverTarget(at: overRight)?.id == WindowID(2))
    }

    @Test("A point over no window owes nothing")
    func gapOwesNothing() {
        let core = makeCore()
        #expect(core.hoverTarget(at: CGPoint(x: 720, y: 400)) == nil)
    }

    @Test("The front-most window at the point wins")
    func frontMostWins() {
        let core = makeCore()
        let float = CGRect(x: 900, y: 300, width: 300, height: 300)
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(3),
                    pid: 13,
                    appName: "F",
                    frame: float,
                    isFloating: true
                )
            )
        )
        // A new window takes the spawn grant; hand it back.
        core.focusWindow(WindowID(1), warp: false)
        core.frontStack = { [left, right] in
            [
                listed(number: 3, pid: 13, frame: float),
                listed(number: 1, pid: 11, frame: left),
                listed(number: 2, pid: 12, frame: right),
            ]
        }
        #expect(core.hoverTarget(at: overRight)?.id == WindowID(3))
        #expect(
            core.hoverTarget(at: CGPoint(x: 800, y: 800))?.id
                == WindowID(2)
        )
    }
}

/// One front-to-back row (#1869); the fields a fixture leaves out
/// are the defaults no stand-down reads.
private func listed(
    number: Int = 0,
    pid: pid_t = 0,
    layer: Int = 0,
    frame: CGRect
) -> KiwiCore.FrontWindow {
    KiwiCore.FrontWindow(
        number: CGWindowID(number),
        pid: pid,
        layer: layer,
        frame: frame
    )
}
