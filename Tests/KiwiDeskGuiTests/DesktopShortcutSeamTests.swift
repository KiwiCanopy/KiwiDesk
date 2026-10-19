import Foundation
import Testing

/// The Desktop shortcut top-up's wirings no unit test reaches:
/// boot and the switch handler both read the live topology.
/// `DesktopShortcutTopUpTests` holds what the top-up does; this
/// holds that both moments still ask it, and that both test-core
/// twins pin the defaults-backed legacy marks (#2324), which a
/// fixture would otherwise read from and clear on the host.
@Suite("The Desktop shortcut top-up stays wired")
struct DesktopShortcutSeamTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    /// needle → (tree, the file that carries it once).
    private static let wirings: [(String, String, String)] =
        [
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
                "ShortcutOffer(desktop: .max, generation: .max)",
                "Tests/KiwiDeskCoreTests", "TestCore.swift"
            ),
            (
                "ShortcutOffer(desktop: .max, generation: .max)",
                "Tests/KiwiDeskGuiTests", "TestCore.swift"
            ),
            (
                "desktopMemory.clearLegacyShortcutOffer = {}",
                "Tests/KiwiDeskCoreTests", "TestCore.swift"
            ),
            (
                "desktopMemory.clearLegacyShortcutOffer = {}",
                "Tests/KiwiDeskGuiTests", "TestCore.swift"
            ),
            (
                "desktopMemory.clearLegacyShortcutOffer()",
                "Sources/KiwiDeskCore/App", "KiwiCore+ConfigArtifacts.swift"
            ),
            (
                "crossLegacyShortcutOffer()",
                "Sources/KiwiDeskCore/App", "KiwiCore+Boot.swift"
            ),
            // Following a sync folder (#2324): boot asks the stored
            // pick, and both twins pin the watch, the pick and the
            // Trash, which would otherwise reach the host.
            (
                "followSyncFolder(sync.storedFolder())",
                "Sources/KiwiDeskCore/App", "KiwiCore+Boot.swift"
            ),
        ]
        + ["Tests/KiwiDeskCoreTests", "Tests/KiwiDeskGuiTests"].flatMap {
            tree in
            [
                "core.sync.makeWatch = { _, _ in nil }",
                "core.sync.watchRequired = false",
                "core.sync.storedFolder = { nil }",
                "core.sync.trash = { try FileManager.default"
                    + ".removeItem(at: $0) }",
            ].map { ($0, tree, "TestCore.swift") }
        }

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
