import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

@MainActor
private func makeCore() -> KiwiCore {
    makeTestCore(
        configDirectory: FileManager.default.temporaryDirectory
            .appendingPathComponent("kiwidesk-tests-\(UUID().uuidString)")
    )
}

private func window(_ id: UInt32, app: String) -> ManagedWindow {
    ManagedWindow(
        id: WindowID(id),
        pid: 100,
        appName: app,
        title: "Doc",
        isFloating: false
    )
}

/// The centred strip through the real builder (#1528 items 17,
/// 20, 21): the active Space centres on the system focus, an
/// inactive one on its remembered focus, each side's hidden
/// windows ride their own disc, the chip keeps one length, and a
/// strip held under the pointer stays until it is released.
@Suite("Space Bar centred strip, built", .serialized)
@MainActor
struct SpaceBarCentredStripTests {
    private let display = DisplayID(7)
    private let one = SpaceID("1")
    private let two = SpaceID("2")

    /// Nine one-window apps in Space 1 (ids 1…9) and Space 2
    /// empty, Space 1 active.
    private func seededCore() -> KiwiCore {
        let core = makeCore()
        core.state.workspaces.assign(one, to: display)
        core.state.workspaces.assign(two, to: display)
        core.state.workspaces.activate(one)
        for id in UInt32(1)...9 {
            core.state.apply(.windowCreated(window(id, app: "App\(id)")))
        }
        return core
    }

    private func item(_ core: KiwiCore, _ space: SpaceID) throws
        -> SpaceBarOverlay.Item
    {
        try #require(
            core.spaceBarItems(display: display, style: SpaceBarLook())
                .first { $0.space == space }
        )
    }

    private func drawn(_ item: SpaceBarOverlay.Item) -> [WindowID] {
        item.apps.flatMap(\.windows)
    }

    @Test("the active Space centres on the focused app")
    func activeCentres() throws {
        let core = seededCore()
        core.state.apply(.windowFocused(WindowID(5)))
        let built = try item(core, one)
        #expect(drawn(built) == (3...7).map { WindowID($0) })
        #expect(built.overflowBefore == [WindowID(1), WindowID(2)])
        #expect(built.overflowWindows == [WindowID(8), WindowID(9)])
        #expect(built.discs == 2)
    }

    @Test("near an end the strip clamps and one disc remains")
    func endClamps() throws {
        let core = seededCore()
        core.state.apply(.windowFocused(WindowID(9)))
        let built = try item(core, one)
        #expect(drawn(built) == (4...9).map { WindowID($0) })
        #expect(built.overflowBefore.count == 3)
        #expect(built.overflowWindows.isEmpty)
        #expect(built.discs == 1)
    }

    /// The chip's measured length is the same wherever the focus
    /// sits — the shelf plans the length the chip draws.
    @Test("the chip's length never moves with the focus")
    func lengthIsFixed() throws {
        let core = seededCore()
        var lengths: Set<CGFloat> = []
        for id in UInt32(1)...9 {
            core.state.apply(.windowFocused(WindowID(id)))
            let built = try item(core, one)
            lengths.insert(
                SpaceBarOverlay.itemLengths(
                    [built],
                    depth: 32,
                    look: SpaceBarLook()
                )[0]
            )
        }
        #expect(lengths.count == 1)
    }

    /// An inactive Space centres on the window it remembers, not
    /// on the system focus, which lives on another Space.
    @Test("an inactive Space centres on its remembered focus")
    func inactiveUsesRememberedFocus() throws {
        let core = seededCore()
        core.state.apply(.windowFocused(WindowID(8)))
        core.state.workspaces.activate(two)
        #expect(core.state.workspaces[one]?.focused == WindowID(8))
        let built = try item(core, one)
        #expect(drawn(built).contains(WindowID(8)))
        #expect(built.overflowWindows.isEmpty)
    }

    @Test("a held strip stays until the pointer leaves")
    func holdKeepsTheStrip() throws {
        let core = seededCore()
        core.state.apply(.windowFocused(WindowID(3)))
        let before = try item(core, one)
        let strip = try #require(before.strip)
        var released = 0
        core.spaceBars.onStripReleased = { released += 1 }
        core.spaceBars.stripHover(one, strip, inside: true)
        core.state.apply(.windowFocused(WindowID(8)))
        #expect(drawn(try item(core, one)) == drawn(before))
        core.spaceBars.stripHover(one, strip, inside: false)
        #expect(released == 1)
        #expect(drawn(try item(core, one)).contains(WindowID(8)))
        // Leaving a chip that held nothing asks for nothing.
        core.spaceBars.stripHover(two, nil, inside: false)
        #expect(released == 1)
    }

    /// A held strip the row no longer draws — a window closed
    /// under the pointer — gives way to the centred one.
    @Test("a held strip the row outgrew is dropped")
    func staleHoldCentres() throws {
        let core = seededCore()
        core.state.apply(.windowFocused(WindowID(9)))
        core.spaceBars.stripHover(one, 3..<9, inside: true)
        core.state.apply(.windowDestroyed(WindowID(1), wasMinimized: false))
        let built = try item(core, one)
        #expect(built.strip == 2..<8)
        #expect(drawn(built).contains(WindowID(9)))
    }
}
