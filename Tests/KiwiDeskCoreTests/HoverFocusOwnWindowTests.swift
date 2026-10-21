import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Hover focus on KiwiDesk's own windows (#1869): the marked one
/// (`OwnWindowTiling`, the Settings window) is focused by Core's
/// command like any window and then fronted by the GUI's
/// `frontOwnWindow`, AppKit's half of #1281's raise; every other
/// own window — the tour, Config Issues, a dialog — stands down.
@Suite("Hover focus on own windows (#1869)", .serialized)
@MainActor
struct HoverFocusOwnWindowTests {
    private let left = CGRect(x: 0, y: 25, width: 700, height: 875)
    private let right = CGRect(x: 740, y: 25, width: 700, height: 875)
    private var overRight: CGPoint { CGPoint(x: 1000, y: 400) }

    /// w1 another app's, w3 KiwiDesk's own, side by side; w1
    /// focused; `marked` decides whether w3 carries the mark.
    private func makeCore(marked: Bool) -> (KiwiCore, Fronts) {
        let directory =
            testTemporaryDirectory
            .appendingPathComponent("kiwidesk-own-\(UUID().uuidString)")
        let core = makeTestCore(configDirectory: directory)
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 25, width: 1440, height: 875)
        }
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: WindowID(1), pid: 11, appName: "A")
            )
        )
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(3),
                    pid: getpid(),
                    appName: "KiwiDesk"
                )
            )
        )
        core.state.apply(.windowMoved(WindowID(1), left))
        core.state.apply(.windowMoved(WindowID(3), right))
        core.focusWindow(WindowID(1), warp: false)
        core.eventLoop.ownWindowIdentifier = { _ in
            marked ? OwnWindowTiling.identifier : "kiwidesk.dialog"
        }
        core.tiler.settings.mouse.hoverFocus = true
        core.frontmostPIDProvider = { 11 }
        core.frontStack = { [left, right] in
            [
                listed(number: 1, pid: 11, frame: left),
                listed(number: 3, pid: getpid(), frame: right),
            ]
        }
        let fronts = Fronts()
        core.mouse.rest.frontOwnWindow = { [weak core] number in
            fronts.numbers.append(number)
            fronts.focusAtFront.append(core?.focusedWindowID)
        }
        return (core, fronts)
    }

    @MainActor
    final class Fronts {
        var numbers: [Int] = []
        /// Core's focus when the GUI was asked to front: the
        /// command comes first (#1281).
        var focusAtFront: [WindowID?] = []
    }

    private func rest(_ core: KiwiCore, at point: CGPoint) {
        core.focusUnderRestingPointer(
            at: GeometryUtils.axPoint(point),
            armedFocus: core.focusedWindowID
        )
    }

    @Test("An own window without the mark stands down")
    func unmarkedOwnStandsDown() {
        let (core, fronts) = makeCore(marked: false)
        #expect(core.hoverTarget(at: overRight) == nil)
        rest(core, at: overRight)
        #expect(core.focusedWindowID == WindowID(1))
        #expect(fronts.numbers.isEmpty)
    }

    @Test("The marked window is focused by Core, then fronted")
    func markedIsFocusedThenFronted() throws {
        let (core, fronts) = makeCore(marked: true)
        let target = try #require(core.hoverTarget(at: overRight))
        #expect(target.own)
        rest(core, at: overRight)
        #expect(core.focusedWindowID == WindowID(3))
        #expect(fronts.numbers == [3])
        #expect(fronts.focusAtFront == [WindowID(3)])
        // The flight names the app the hover left (#1812).
        #expect(core.raiseFlight?.leftPID == 11)
    }

    /// A focus the Desktop raise gate refuses (#1345) moves
    /// nothing, so the GUI is never asked for the bare front #1281
    /// exists to prevent.
    @Test("A refused focus is not fronted")
    func refusedFocusIsNotFronted() {
        let (core, fronts) = makeCore(marked: true)
        core.windowIsOnScreen = { $0 == WindowID(3) ? false : nil }
        rest(core, at: overRight)
        #expect(core.focusedWindowID == WindowID(1))
        #expect(fronts.numbers.isEmpty)
    }

    @Test("Another app's window is never fronted by the GUI")
    func otherAppIsNotFronted() {
        let (core, fronts) = makeCore(marked: true)
        core.focusWindow(WindowID(3), warp: false)
        core.frontmostPIDProvider = { getpid() }
        rest(core, at: CGPoint(x: 300, y: 400))
        #expect(core.focusedWindowID == WindowID(1))
        #expect(fronts.numbers.isEmpty)
    }

    /// The marked window on the other screen's shown Space: that
    /// Space becomes the active one, as a click there makes it,
    /// and the window is focused and fronted.
    @Test("The marked window on another screen takes that screen")
    func markedOnAnotherScreen() throws {
        let (core, fronts) = makeCore(marked: true)
        let here = try #require(core.activeSpace?.id)
        let there = SpaceID("hover-other")
        for display in [
            Display(
                id: DisplayID(1),
                name: "A",
                frame: CGRect(x: 0, y: 0, width: 100, height: 100)
            ),
            Display(
                id: DisplayID(2),
                name: "B",
                frame: CGRect(x: 100, y: 0, width: 100, height: 100)
            ),
        ] {
            core.state.workspaces.upsertDisplay(display)
        }
        core.state.workspaces.ensureSpace(there)
        core.state.workspaces.assign(here, to: DisplayID(1))
        core.state.workspaces.assign(there, to: DisplayID(2))
        core.state.workspaces.activate(there)
        core.state.workspaces.remove(WindowID(3))
        core.state.workspaces.add(WindowID(3), to: there)
        core.state.workspaces.activate(here)
        core.state.workspaces.show(there, on: DisplayID(2))
        core.focusWindow(WindowID(1), warp: false)
        try #require(core.state.workspaces.visibleSpaces.contains(there))
        rest(core, at: overRight)
        #expect(core.state.workspaces.activeSpace == there)
        #expect(core.focusedWindowID == WindowID(3))
        #expect(fronts.numbers == [3])
    }
}

/// One front-to-back row; the fields a fixture leaves out are the
/// defaults no stand-down reads.
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
