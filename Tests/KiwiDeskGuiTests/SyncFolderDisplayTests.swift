import Foundation
import Testing

@testable import KiwiDesk

/// How the row and the sheet name a folder (#2324 slice 2): as the
/// user named it, never through a symlink's target. Cheap: one temp
/// link per test, off the main actor.
@Suite("Sync folder display (#2324)")
struct SyncFolderDisplayTests {
    @Test("a symlinked folder keeps the name it was chosen by")
    func symlinkIsNotFollowed() throws {
        let root =
            testTemporaryDirectory
            .appendingPathComponent("kiwi-sync-display-\(UUID().uuidString)")
        let target = root.appendingPathComponent("real-target")
        let link = root.appendingPathComponent("chosen-link")
        try FileManager.default.createDirectory(
            at: target,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createSymbolicLink(
            at: link,
            withDestinationURL: target
        )
        let shown = SyncFolderDisplay.path(link)
        #expect(shown.hasSuffix("▸ chosen-link"))
        #expect(!shown.contains("real-target"))
    }

    @Test("a folder in the home folder starts at ~")
    func homeIsATilde() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let url = home.appendingPathComponent("kiwi-no-such-dir/Sync")
        let shown = SyncFolderDisplay.path(url)
        #expect(shown == "~ ▸ kiwi-no-such-dir ▸ Sync")
    }

    @Test("each folder takes Finder's localized name")
    func componentsAreDisplayNames() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let url = home.appendingPathComponent("Documents/Sync")
        let shown = SyncFolderDisplay.path(url) {
            "<" + ($0 as NSString).lastPathComponent + ">"
        }
        #expect(shown == "~ ▸ <Documents> ▸ <Sync>")
    }
}
