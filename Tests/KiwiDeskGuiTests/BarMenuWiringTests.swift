import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The bars' right-click menus' GUI wiring (#1518), which no suite
/// drives: the hooks Core's rows call, the call that wires
/// them at launch, and the one Keep save both Layout menus take.
@Suite("Bar menu wiring (#1518)")
struct BarMenuWiringTests {
    private func squashed(_ path: String) throws -> String {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/" + path)
        return SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        ).split(whereSeparator: \.isWhitespace).joined()
    }

    @Test("every hook a bar menu calls is wired")
    func hooksAreWired() throws {
        let wiring = try squashed("AppDelegate+BarMenus.swift")
        for needle in [
            "core.barMenuHooks.openSettings={[weakself]landingin"
                + "self?.dashboard.show(landing:landing)}",
            "core.barMenuHooks.keepLayout={[weakself]in"
                + "self?.keepLayoutInProfile()}",
            // #2869: the one live-chord reader, by exact Lua body.
            "core.barMenuHooks.menuChord={[weakcore]verbin"
                + "core.flatMap{ShortcutsOpenBinding.combo(core:$0,"
                + "lua:Self.lua(of:verb))}}",
            // #2941: an empty Pocket's chords, each verb its own.
            "core.barMenuHooks.pocketVerbChord={[weakcore]verbin"
                + "core.flatMap{ShortcutsOpenBinding.rendered(core:$0,"
                + "lua:Self.pocketLua(of:verb))}}",
            "core.barMenuHooks.layoutChar=LayoutKeyGlyph.char",
        ] {
            #expect(wiring.contains(needle), Comment(rawValue: needle))
        }
    }

    /// A bar menu row shows a chord only for its catalog body
    /// (#2869 ▸ 2), so a verb mapped to another row's body draws
    /// that row's key.
    @Test("each menu verb reads its own catalog row")
    @MainActor
    func verbsReadTheirRows() {
        #expect(
            AppDelegate.lua(of: .toggleFloating)
                == "KiwiDesk.toggle_floating()"
        )
        #expect(
            AppDelegate.lua(of: .togglePocketWindow)
                == "KiwiDesk.toggle_pocket_window()"
        )
        // An empty Pocket's two keys (#2941).
        #expect(AppDelegate.pocketLua(of: .pocket) == "KiwiDesk.pocket()")
        #expect(
            AppDelegate.pocketLua(of: .togglePocketWindow)
                == "KiwiDesk.toggle_pocket_window()"
        )
    }

    /// The bar menus' wiring runs at launch; their Keep reaches
    /// the one save above, as KiwiHub's View side does.
    @Test("the launch wires the bar menus")
    func launchWiresTheMenus() throws {
        let delegate = try squashed("AppDelegate.swift")
        #expect(delegate.contains("wireBarMenus()"))
    }
}
