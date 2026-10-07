import Foundation
import Testing

/// The bar menus' two machine-touching seams stay pinned in BOTH
/// `makeTestCore` twins (#1518, #1528): the Quit row's
/// `terminateApp`, whose live default terminates the real process
/// owning a fixture pid, the glyph menu's modal `present`, and the
/// hover peek's dwell timer, which would open a panel (#1946).
/// Deleting a pin from both twins is otherwise silent — the
/// twins-identical scan in `MachineTouchTests` sees only a
/// one-sided deletion. The `MouseButtonSeamGuardTests` shape.
///
/// The glyph menu also pops as a CONTEXT menu, the right-click
/// menu's chrome (#1850): a pop-up-button `popUp(positioning:)`
/// draws different chrome on macOS 26+.
///
/// Residue: each needle is one spelling, so a pin re-written
/// equivalently reads as missing. Fail-closed, and the message
/// names the target it is missing from.
@Suite("Bar menu seams are pinned in the test cores")
struct BarMenuSeamGuardTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    @Test("makeTestCore pins the bar menus' machine seams")
    func testCorePinsBarMenuSeams() throws {
        for target in ["KiwiDeskCoreTests", "KiwiDeskGuiTests"] {
            let twin = Self.root.appendingPathComponent(
                "Tests/\(target)/TestCore.swift"
            )
            let source = try SourceScan.strippedSource(at: twin)
            #expect(
                source.contains(
                    "shelves.contextMenus.terminateApp = { _ in }"
                )
                    && source.contains(
                        "spaceBars.glyphActions.present = { _, _ in }"
                    )
                    && source.contains(
                        "shelves.peek.schedule = { _, _ in }"
                    ),
                .init(rawValue: "\(target) misses a pin")
            )
        }
    }

    @Test("the glyph menu pops as a context menu at its cell")
    func glyphMenuWearsContextChrome() throws {
        let file = Self.root.appendingPathComponent(
            "Sources/KiwiDeskCore/Bar/SpaceBarGlyphTarget.swift"
        )
        let source = try SourceScan.strippedSource(at: file)
        let count = { (needle: String) in
            source.components(separatedBy: needle).count - 1
        }
        #expect(
            count(
                "NSMenu.popUpContextMenu(menu, with: event, for: anchor)"
            ) == 1
        )
        // The event sits at the anchor, sized by the menu it pops.
        #expect(count("SpaceBarGlyphActions.contextEvent(") == 1)
        #expect(count("at: anchor,") == 1)
        #expect(count("menu: menu.size") == 1)
        #expect(count("popUp(positioning:") == 0)
    }
}
