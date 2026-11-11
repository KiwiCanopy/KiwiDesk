import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The host's `com.apple.symbolichotkeys` is read through two seams
/// alone (#1105, #3173): Settings' `readSymbolicHotkey` and the key
/// manager's. A direct read beside them reads the developer's plist
/// in every suite that reaches it.
@Suite("Symbolic hotkey seams (#3173)")
struct SymbolicHotkeySeamTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    @Test("the plist reader is called from the two seam defaults only")
    func twoSeams() throws {
        var hits: [String: Int] = [:]
        for tree in ["Sources/KiwiDesk", "Sources/KiwiDeskCore"] {
            let files = try SourceScan.swiftSources(
                under: Self.root.appendingPathComponent(tree)
            )
            #expect(!files.isEmpty)
            for url in files {
                let count = try SourceScan.strippedSource(at: url)
                    .occurrences(of: "SymbolicHotkeys.liveRead(")
                if count > 0 { hits[url.lastPathComponent] = count }
            }
        }
        // The manager's default names the reader without calling it.
        #expect(hits == ["SystemShortcutEnablement.swift": 1])
        let manager = try SourceScan.strippedSource(
            at: Self.root.appendingPathComponent(
                "Sources/KiwiDeskCore/Keys/KeybindingManager.swift"
            )
        ).filter { !$0.isWhitespace }
        #expect(
            manager.contains(
                "varreadSymbolicHotkey:(Int)->SymbolicHotkeyEntry?="
                    + "SymbolicHotkeys.liveRead"
            )
        )
        #expect(manager.occurrences(of: "SymbolicHotkeys.liveRead") == 1)
    }

    @Test("both test factories pin the manager's read inert")
    func factoriesPin() throws {
        for path in [
            "Tests/KiwiDeskCoreTests/TestCore.swift",
            "Tests/KiwiDeskGuiTests/TestCore.swift",
        ] {
            let text = try SourceScan.strippedSource(
                at: Self.root.appendingPathComponent(path)
            ).filter { !$0.isWhitespace }
            #expect(
                text.contains("core.keys.readSymbolicHotkey={_innil}"),
                "\(path) leaves the host's plist live"
            )
        }
    }

    /// An open sequence swallows exactly the chords every app's
    /// menus carry: one set, read from both sides.
    @Test("the swallowed tier is the app accelerators")
    func swallowedIsAccelerators() {
        for shortcut in SystemShortcut.allCases {
            #expect(
                (shortcut.sequenceTier == .swallowed)
                    == shortcut.isUniversalAccelerator,
                "\(shortcut)"
            )
        }
    }
}
