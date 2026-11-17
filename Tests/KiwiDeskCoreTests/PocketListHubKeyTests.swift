import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// Two pocketable windows on the real main screen, the Space Bar at the
/// top, so the pocket's own edge draws nothing; Hidden by default.
/// The pocket's real panels order in, so its suites need a main screen.
@MainActor
private struct PocketListFixture {
    let one = WindowID(1)
    let two = WindowID(2)
    let core: KiwiCore
    let display: DisplayID

    init() throws {
        core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-list-\(UUID().uuidString)")
        )
        for id in [one, two] {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: id,
                        pid: 900_000 + pid_t(id.raw),
                        appName: "App\(id.raw)",
                        title: "Window \(id.raw)",
                        frame: CGRect(x: 100, y: 100, width: 600, height: 400)
                    )
                )
            )
        }
        let screen = try #require(NSScreen.main)
        display = try #require(screen.kiwiDisplayID)
        let space = try #require(core.state.workspaces.activeSpace)
        core.state.workspaces.upsertDisplay(
            Display(id: display, name: "Main", frame: screen.frame)
        )
        core.state.workspaces.assign(space, to: display)
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 25, width: 1440, height: 800)
        }
        core.tiler.settings.spaceBarStyle.edge = .top
        core.tiler.settings.spaceBarStyle.visibility = .hidden
        core.tiler.settings.kiwishelf.pocketEdge = .bottom
        core.pocketPlate.ordersPanel = true
        core.shelves.peek.visibleArea = { _ in
            CGRect(x: -20_000, y: -20_000, width: 40_000, height: 40_000)
        }
    }

    func tearDown() {
        core.shelves.peek.dismiss()
        core.shelves.peek.panel.panel?.orderOut(nil)
        core.pocketPlate.sync([])
        NativeSpaces.currentSpaceIsUserOverride = nil
    }

    /// Pockets `ids`, Several windows holding them.
    func pocket(_ ids: [WindowID]) {
        core.execute(
            "kiwishelf.set_pocket_visibility",
            args: [.string("always")]
        )
        for id in ids {
            core.handle(.windowFocused(id))
            core.execute("toggle_pocket_window")
            core.execute("pocket")
            #expect(core.state.isPocketed(id))
        }
        core.updatePocketPlate(slots: [:])
    }
}

/// The Pocket's key-opened list walks with KiwiHub's ↑ ↓ alternatives
/// (`kiwihub.set_key`, #3398), read through the core's wiring.
@Suite(
    "The Pocket list walks with KiwiHub's key alternatives",
    .serialized,
    .enabled(if: NSScreen.main != nil)
)
@MainActor
struct PocketListHubKeyTests {
    private let one = WindowID(1)
    private let two = WindowID(2)
    private static let jKey: UInt16 = 38
    private static let kKey: UInt16 = 40
    private static let dKey: UInt16 = 2

    private func setKey(_ core: KiwiCore, _ key: String, _ combo: String) {
        let reply = core.execute(
            "kiwihub.set_key",
            args: [.string(key), .string(combo)]
        )
        #expect(reply.isSuccess)
    }

    @Test("⌃J and ⌃K walk the list once set, and close it before")
    func controlAlternativesWalk() throws {
        let fixture = try PocketListFixture()
        let core = fixture.core
        defer { fixture.tearDown() }
        fixture.pocket([one, two])
        core.execute("pocket.toggle_list")
        let panel = core.shelves.peek.panel
        let window = try #require(panel.panel)
        // Unset, ⌃J is a key the list does not use: it closes.
        window.keyDown(with: key(Self.jKey, "j", [.control]))
        #expect(core.shelves.peek.shown == nil)
        setKey(core, "down", "ctrl+j")
        setKey(core, "up", "ctrl+k")
        core.execute("pocket.toggle_list")
        window.keyDown(with: key(Self.jKey, "j", [.control]))
        #expect(panel.body.hovered == 1)
        // ⇧ held moves as with the arrows, as KiwiHub's does.
        window.keyDown(with: key(Self.kKey, "K", [.control, .shift]))
        #expect(panel.body.hovered == 0)
        #expect(core.shelves.peek.shown != nil)
    }

    @Test("a ⌘ alternative walks rather than closing the list")
    func commandAlternativeWalks() throws {
        let fixture = try PocketListFixture()
        let core = fixture.core
        defer { fixture.tearDown() }
        fixture.pocket([one, two])
        setKey(core, "down", "cmd+j")
        let view = try #require(core.pocketPlate.view(on: fixture.display))
        // A click's list walks no held chord of its own.
        core.pocketPlate.onClick(view)
        let panel = core.shelves.peek.panel
        let window = try #require(panel.panel)
        #expect(
            window.performKeyEquivalent(
                with: key(Self.jKey, "j", [.command])
            )
        )
        #expect(panel.body.hovered == 0)
        #expect(core.shelves.peek.shown != nil)
    }

    @Test("a page alternative is KiwiHub's alone and closes the list")
    func pageAlternativeCloses() throws {
        let fixture = try PocketListFixture()
        let core = fixture.core
        defer { fixture.tearDown() }
        fixture.pocket([one, two])
        setKey(core, "page_down", "ctrl+d")
        core.execute("pocket.toggle_list")
        let window = try #require(core.shelves.peek.panel.panel)
        window.keyDown(with: key(Self.dKey, "d", [.control]))
        #expect(core.shelves.peek.shown == nil)
    }

    private func key(
        _ code: UInt16,
        _ text: String,
        _ flags: NSEvent.ModifierFlags
    ) -> NSEvent {
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: flags,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: text,
            charactersIgnoringModifiers: text,
            isARepeat: false,
            keyCode: code
        )!
    }
}
