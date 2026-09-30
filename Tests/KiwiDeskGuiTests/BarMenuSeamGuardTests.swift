import Foundation
import Testing

/// The bar menus' two machine-touching seams stay pinned in BOTH
/// `makeTestCore` twins (#1518, #1528): the Quit row's
/// `terminateApp`, whose live default terminates the real process
/// owning a fixture pid, and the glyph menu's modal `present`.
/// Deleting a pin from both twins is otherwise silent — the
/// twins-identical scan in `MachineTouchTests` sees only a
/// one-sided deletion. The `MouseButtonSeamGuardTests` shape.
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
                    ),
                .init(rawValue: "\(target) misses a pin")
            )
        }
    }
}
