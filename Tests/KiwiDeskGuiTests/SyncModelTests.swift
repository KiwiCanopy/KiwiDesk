import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// Compare and Copy's model doors (#2324 slice 2): a refusal keeps
/// the draft, and a Save that cannot land copies nothing. Cheap on
/// the main actor: one test core and a temp folder per test.
@Suite("Sync model doors (#2324)", .serialized)
@MainActor
struct SyncModelTests {
    private func emptyFolder() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("kiwi-sync-model-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true
        )
        return url
    }

    @Test("a refused Keep the Folder's keeps the unsaved edits")
    func refusalKeepsTheDraft() throws {
        let model = makeTestModel()
        model.isDirty = true
        let refusal = model.keepFoldersSetup(from: try emptyFolder())
        #expect(refusal == .folderEmpty)
        #expect(model.isDirty)
    }

    @Test("a blocked Save copies nothing into the folder")
    func blockedSaveCopiesNothing() throws {
        let model = makeTestModel()
        model.isDirty = true
        let folder = try emptyFolder()
        guard model.syncSaveBlockedReason != nil else {
            Issue.record("expected the fixture's Save to be blocked")
            return
        }
        #expect(model.keepThisMacsSetup(in: folder) == nil)
        // A blocked Save is never attempted, so it asks for nothing.
        #expect(!model.newProfileNamingRequested)
        let names = try FileManager.default.contentsOfDirectory(
            atPath: folder.path
        )
        #expect(names.isEmpty)
    }

    @Test("the sync folder lives in the model's preferences")
    func folderLivesInPreferences() throws {
        let defaults = UserDefaults(
            suiteName: "kiwi-sync-\(UUID().uuidString)"
        )!
        let model = makeTestModel(defaults: defaults)
        let folder = try emptyFolder()
        model.syncFolder = folder
        #expect(
            SyncFolderLocation.stored(in: defaults)?.standardizedFileURL
                .path == folder.standardizedFileURL.path
        )
        model.syncFolder = nil
        #expect(SyncFolderLocation.stored(in: defaults) == nil)
    }
}
