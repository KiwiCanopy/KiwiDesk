import Foundation
import Testing

/// A look's picture touches the host twice (#3478): a wallpaper set,
/// which macOS keeps past the test process, and the Trash. Both
/// `makeTestCore` twins pin them, and a pin deleted from both reds
/// nothing else, since every suite would then set the developer's
/// real wallpaper with no assertion reading it. Matched on one
/// spelling each, so a pin re-written equivalently reads as missing.
@Suite("Look wallpaper seams are pinned in both test cores")
struct LookWallpaperSeamPinTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    @Test("both twins refuse the set and keep the Trash out")
    func twinsPinTheSeams() throws {
        for target in ["KiwiDeskCoreTests", "KiwiDeskGuiTests"] {
            let twin = Self.root.appendingPathComponent(
                "Tests/\(target)/TestCoreDesktopPins.swift"
            )
            let source = try SourceScan.strippedSource(at: twin)
            #expect(!source.isEmpty, "\(target): nothing read")
            #expect(
                source.contains("lookWallpaperSeams.desk = .refused"),
                "\(target) does not refuse the wallpaper set"
            )
            #expect(
                source.contains(
                    "lookWallpaperSeams.trash = {\n"
                        + "        try FileManager.default.removeItem"
                ),
                "\(target) does not keep the Trash out"
            )
        }
    }
}
