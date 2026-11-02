import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// An app's own pocket window in the pocket's list (#2923 ▸ Ruling):
/// listed after the general list under the Pocket Keys header, its
/// row wearing the app's key, picked as any row is; the plate's
/// count and fade read both, the capacity the general list alone.
@Suite("The pocket's list holds the apps' own windows (#2923)", .serialized)
@MainActor
struct PocketListKeyedTests {
    typealias Fixture = PocketAppFixture
    private let mine = WindowID(9)
    private let general = WindowID(1)

    /// Several windows; the app's window pocketed through its key,
    /// then the other app's window put in the general list.
    private func fixture(general put: Bool = true) -> Fixture {
        let fixture = Fixture()
        fixture.core.execute("pocket.set_capacity", args: [.string("several")])
        fixture.press()
        fixture.arrive(9)
        fixture.press()
        #expect(fixture.core.state.isPocketed(mine))
        guard put else { return fixture }
        fixture.core.handle(.windowFocused(general))
        fixture.core.execute("toggle_pocket_window")
        fixture.core.execute("pocket")
        #expect(fixture.core.state.isPocketed(general))
        return fixture
    }

    @Test("the plate lists the general list, then the keyed window")
    func plateListsBoth() {
        let fixture = fixture()
        #expect(fixture.core.pocketPlateWindows == [general, mine])
        // Capacity still counts the general list alone (▸ 5).
        #expect(fixture.core.state.generalPocket.map(\.window) == [general])
    }

    @Test("the list draws the keyed window last, with its key")
    func contentKeysTheLastGroup() throws {
        let fixture = fixture()
        let core = fixture.core
        core.barMenuHooks.pocketKeyChord = { app in
            app == Fixture.app
                ? RenderedChord(drawn: "⌃⌥T", spoken: "Control Option T")
                : nil
        }
        let content = try #require(
            core.barPeekContent(.pocket(core.pocketPlateWindows), on: nil)
        )
        #expect(content.groups.map(\.keyed) == [false, true])
        #expect(content.groups.last?.rows.map(\.window) == [mine])
        #expect(content.groups.last?.rows.first?.chord == "⌃⌥T")
        #expect(content.groups.first?.rows.first?.chord == nil)
        // No other list keys a row.
        let glyph = try #require(
            core.barPeekContent(.overflow([general, mine]), on: nil)
        )
        let keyedGroups = glyph.groups.filter(\.keyed)
        #expect(keyedGroups.isEmpty)
    }

    @Test(
        "a keyed window alone lifts the fade and counts",
        .enabled(if: NSScreen.main != nil)
    )
    func keyedAloneCounts() throws {
        let fixture = fixture(general: false)
        let core = fixture.core
        // A real screen, so the fallback square resolves (#531).
        let screen = try #require(NSScreen.main)
        let id = try #require(screen.kiwiDisplayID)
        let space = try #require(core.state.workspaces.activeSpace)
        core.state.workspaces.upsertDisplay(
            Display(id: id, name: "Main", frame: screen.frame)
        )
        core.state.workspaces.assign(space, to: id)
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 25, width: 1440, height: 800)
        }
        core.updatePocketPlate()
        let spec = try #require(fixture.core.pocketPlate.specs.values.first)
        #expect(!spec.faded)
        #expect(spec.windows == [mine])
    }

    /// "Nothing changes under One window" (▸ 2): a drag or a play
    /// stands the pocket there, and it counts the general list.
    @Test("under One window the plate counts the general list alone")
    func oneWindowCountsGeneral() {
        let fixture = fixture()
        fixture.core.execute("pocket.set_capacity", args: [.string("one")])
        #expect(fixture.core.pocketPlateWindows == [general])
    }

    /// The pocket's VoiceOver menu: the keyed window last, keyed.
    @Test("the pocket's menu sets the keyed window apart with its key")
    func menuKeysTheRow() throws {
        let fixture = fixture()
        let core = fixture.core
        core.barMenuHooks.pocketKeyChord = { _ in
            RenderedChord(drawn: "⌃⌥T", spoken: "Control Option T")
        }
        var shown: NSMenu?
        core.spaceBars.glyphActions.present = { menu, _ in shown = menu }
        core.presentBarWindowMenu(
            core.pocketPlateWindows,
            kind: .overflow,
            space: nil,
            at: NSView(),
            keyed: true
        )
        let menu = try #require(shown)
        LocalizationManager.shared.select("en")
        let header = try #require(
            menu.items.first { $0.isSectionHeader }
        )
        #expect(menu.index(of: header) == 1)
        let last = try #require(menu.items.last)
        if #available(macOS 14.4, *) {
            #expect(last.subtitle == "⌃⌥T")
            #expect(menu.items.first?.subtitle == nil)
        }
        #expect(
            last.accessibilityLabel()?.hasSuffix("Pocket key Control Option T")
                == true
        )
    }

    /// A pick elsewhere takes it out and the key keeps its tie (▸ 11).
    @Test("its row takes it out; the key still owns it")
    func rowTakesOut() {
        let fixture = fixture()
        fixture.core.pickBarRow(mine, on: nil)
        #expect(fixture.core.state.pocketPhase(of: mine) == .out)
        #expect(fixture.owner(of: mine) == Fixture.app)
        #expect(fixture.core.state.isPocketed(general))
    }
}
