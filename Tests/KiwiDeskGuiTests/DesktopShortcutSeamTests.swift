import Foundation
import Testing

/// The Desktop shortcut top-up's wirings no unit test reaches:
/// boot and the switch handler both read the live topology.
/// `DesktopShortcutTopUpTests` holds what the top-up does; this
/// holds that both moments still ask it, and that both test-core
/// twins pin the defaults-backed mark, which a fixture would
/// otherwise read from and write to the host.
@Suite("The Desktop shortcut top-up stays wired")
struct DesktopShortcutSeamTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    /// needle → (tree, the file that carries it once).
    private static let wirings: [(String, String, String)] = [
        (
            "self?.topUpDesktopShortcuts(desktops: desktops)",
            "Sources/KiwiDeskCore", "KiwiCore+Desktops.swift"
        ),
        (
            "self?.dashboardIfCreated?.adoptShortcutAdd(rows)",
            "Sources/KiwiDesk", "AppDelegate.swift"
        ),
        (
            "onShortcutsAdded(rows)",
            "Sources/KiwiDeskCore", "KiwiCore+ShortcutTopUp.swift"
        ),
        (
            "topUpDesktopShortcuts(",
            "Sources/KiwiDeskCore/App", "KiwiCore+Boot.swift"
        ),
        (
            "desktopMemory.readShortcutMark = { .max }",
            "Tests/KiwiDeskCoreTests", "TestCore.swift"
        ),
        (
            "desktopMemory.readShortcutMark = { .max }",
            "Tests/KiwiDeskGuiTests", "TestCore.swift"
        ),
    ]

    @Test("each wiring exists exactly once, in its own file")
    func wiringsAreSingular() throws {
        for (needle, tree, file) in Self.wirings {
            let sites = try SourceScan.identifierSites(
                of: needle,
                under: Self.root.appendingPathComponent(tree)
            ).filter { $0.file.lastPathComponent == file }
            #expect(
                sites.count == 1,
                "expected one `\(needle)` in \(tree)/\(file)"
            )
        }
    }
}
