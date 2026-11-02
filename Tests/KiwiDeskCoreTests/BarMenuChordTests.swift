import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// The live chord beside a bar menu row (#2869, the owner's ruling
/// in its body): drawn in the key-equivalent column on Float /
/// Tile and Remove from Pocket only, only in a single-window menu
/// whose window holds the focus, and never fired twice.
@Suite("Bar menu live chords", .serialized)
@MainActor
struct BarMenuChordTests {
    private let one = SpaceID("1")
    private let two = SpaceID("2")
    private let floatChord = KeyCombo.parse("ctrl+alt+f")!
    private let pocketChord = KeyCombo.parse("ctrl+alt+shift+p")!

    /// Windows 1 and 2 of "Safari" (pid 41) and window 3 of "Notes"
    /// (pid 42) on Space 1; every verb bound; window 3 focused.
    private func seededCore() -> KiwiCore {
        LocalizationManager.shared.select("en")
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-menu-chord-\(UUID())")
        )
        let display = DisplayID(7)
        core.state.workspaces.upsertDisplay(
            Display(
                id: display,
                name: "Desk",
                frame: CGRect(x: 0, y: 0, width: 1000, height: 600)
            )
        )
        core.state.workspaces.assign(one, to: display)
        core.state.workspaces.assign(two, to: display)
        core.state.workspaces.activate(one)
        for (raw, pid, app) in [
            (UInt32(1), pid_t(41), "Safari"), (2, 41, "Safari"),
            (3, 42, "Notes"),
        ] {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(raw),
                        pid: pid,
                        appName: app,
                        appBundleID: "com.example.\(app)",
                        title: "Page \(raw)"
                    )
                )
            )
        }
        core.state.apply(.windowFocused(WindowID(3)))
        let chords: [BarMenuVerb: KeyCombo] = [
            .toggleFloating: floatChord,
            .togglePocketWindow: pocketChord,
        ]
        core.barMenuHooks.menuChord = { chords[$0] }
        return core
    }

    private final class Press { var event: NSEvent? }

    /// A keyDown of `keyCode` with `modifiers` held.
    private func press(
        _ keyCode: UInt16,
        _ modifiers: NSEvent.ModifierFlags
    ) -> NSEvent? {
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifiers,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "",
            charactersIgnoringModifiers: "",
            isARepeat: false,
            keyCode: keyCode
        )
    }

    private func rows(_ core: KiwiCore, _ ids: [UInt32]) -> [BarMenuRow] {
        core.barMenuRows(.appItem(ids.map(WindowID.init)))
    }

    private func chords(_ rows: [BarMenuRow]) -> [String: KeyCombo] {
        var found: [String: KeyCombo] = [:]
        for row in rows {
            if let chord = row.chord { found[row.title] = chord }
            if case .submenu(let children) = row.kind {
                found.merge(chords(children)) { first, _ in first }
            }
        }
        return found
    }

    @Test("the focused window's Float row carries the chord alone")
    func focusedFloatRow() {
        let core = seededCore()
        #expect(chords(rows(core, [3])) == ["Float Window": floatChord])
        core.execute("make_floating", args: [.number(3)])
        #expect(chords(rows(core, [3])) == ["Tile Window": floatChord])
    }

    @Test("another window's menu shows no chord")
    func otherWindowShowsNone() {
        let core = seededCore()
        #expect(chords(rows(core, [1])).isEmpty)
    }

    /// The group's child naming the focused window included.
    @Test("a group menu shows no chord, parent or child")
    func groupShowsNone() {
        let core = seededCore()
        core.state.apply(.windowFocused(WindowID(1)))
        #expect(chords(rows(core, [1, 2])).isEmpty)
    }

    @Test("Remove from Pocket carries the pocket chord, Pocket none")
    func removeFromPocketRow() {
        let core = seededCore()
        core.execute("toggle_pocket_window", args: [.number(3)])
        core.state.apply(.windowFocused(WindowID(3)))
        let menu = rows(core, [3])
        #expect(menu.contains { $0.title == "Pocket Window" })
        #expect(chords(menu) == ["Remove from Pocket": pocketChord])
    }

    /// The pocket window of a mixed group, focused: its Remove
    /// child names the window the key acts on, and still shows none.
    @Test("a mixed group's focused pocket child shows no chord")
    func mixedGroupShowsNone() {
        let core = seededCore()
        core.execute("toggle_pocket_window", args: [.number(1)])
        core.state.apply(.windowFocused(WindowID(1)))
        let menu = rows(core, [1, 2])
        #expect(menu.contains { $0.title == "Remove from Pocket" })
        #expect(chords(menu).isEmpty)
    }

    /// The bars' last focus outlives a switch to an empty Space,
    /// where the key acts on no window (#2869 ▸ 3).
    @Test("a focus the key no longer acts on shows no chord")
    func leftFocusShowsNone() {
        let core = seededCore()
        core.state.workspaces.activate(two)
        #expect(core.barFocus(on: nil) == WindowID(3))
        #expect(core.focusedWindowID == nil)
        #expect(chords(rows(core, [3])).isEmpty)
    }

    /// The gate itself: a row's window inside a wider menu set.
    @Test("the gate refuses a window inside a group's set")
    func gateReadsTheMenuSet() {
        let core = seededCore()
        let id = WindowID(3)
        #expect(core.barMenuChord(.toggleFloating, for: id, in: [id]) != nil)
        #expect(
            core.barMenuChord(
                .toggleFloating,
                for: id,
                in: [id, WindowID(1)]
            ) == nil
        )
    }

    @Test("an unbound verb shows nothing")
    func unboundShowsNone() {
        let core = seededCore()
        core.barMenuHooks.menuChord = { _ in nil }
        #expect(chords(rows(core, [3])).isEmpty)
    }

    /// Carbon's hotkey is the action; AppKit's matching keyDown is
    /// dropped, or Float toggles twice (#2869 ▸ 5). Return on the
    /// row the arrow keys picked is the row's own firing.
    @Test("only the drawn chord's own keyDown is dropped")
    func keyDownDropped() throws {
        let core = seededCore()
        let current = Press()
        core.shelves.contextMenus.keyDown = { current.event }
        core.barMenuHooks.layoutChar = { $0 == 3 ? "f" : nil }
        // Fires the Float / Tile row of a menu opened now.
        let fire = { (event: NSEvent?) throws in
            let menu = try #require(
                core.shelves.contextMenus.menu(for: .appItem([WindowID(3)]))
            )
            let item = try #require(
                menu.items.first { !$0.keyEquivalent.isEmpty }
            )
            #expect(item.keyEquivalent == "f")
            #expect(item.keyEquivalentModifierMask == [.control, .option])
            let target = try #require(item.target as? NSObject)
            let action = try #require(item.action)
            current.event = event
            target.perform(action, with: item)
        }
        let floats = { core.state.windows[WindowID(3)]?.isFloating }
        try fire(press(3, [.control, .option]))
        #expect(floats() == false)
        try fire(press(3, [.control, .option, .shift]))
        #expect(floats() == true)
        try fire(press(36, []))
        #expect(floats() == false)
        try fire(nil)
        #expect(floats() == true)
    }

    /// A chord the column could not draw drops nothing: Carbon
    /// answers no press the row did not promise.
    @Test("an undrawn chord's row fires on its keyDown")
    func undrawnChordFires() throws {
        var fired = 0
        let menu = BarMenu.make(
            [.action("Float Window", chord: floatChord) { fired += 1 }],
            layoutChar: { _ in nil },
            keyDown: { [self] in press(3, [.control, .option]) }
        )
        let item = try #require(menu.items.first)
        #expect(item.keyEquivalent.isEmpty)
        let target = try #require(item.target as? NSObject)
        let action = try #require(item.action)
        target.perform(action, with: item)
        #expect(fired == 1)
    }

    @Test("a sided chord draws nothing, its unsided twin draws")
    func sidedDrawsNothing() throws {
        let sided = try #require(KeyCombo.parse("rctrl+alt+f"))
        let menu = BarMenu.make(
            [
                .action("Sided", chord: sided) {},
                .action("Plain", chord: floatChord) {},
            ],
            layoutChar: { _ in "f" },
            keyDown: { nil }
        )
        #expect(menu.items.map(\.keyEquivalent) == ["", "f"])
    }

    /// The menu speaks the key equivalent natively (#2869 ▸ 7).
    @Test("VoiceOver's action names carry no chord")
    func voiceOverNamesNoChord() {
        LocalizationManager.shared.select("en")
        let actions = BarMenu.accessibilityActions(
            [.action("Float Window", chord: floatChord) {}]
        )
        #expect(actions.map(\.name) == ["Float Window"])
    }
}
