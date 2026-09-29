import Foundation
import Testing

@testable import KiwiDeskCore

/// The look library, `looks.json` (#1684): the palette store's
/// invariants, plus an export carrying the look's own colours
/// (#1752).
@Suite("Look store")
struct LookStoreTests {
    private func store() -> LookStore {
        LookStore(
            directory: FileManager.default.temporaryDirectory
                .appendingPathComponent("looks-\(UUID().uuidString)")
        )
    }

    private func look(_ name: String) -> ShelfLook {
        ShelfLook(
            name: name,
            style: ["kiwishelf.thickness": .number(30)],
            colors: ["kiwishelf.fill_color": "#112233"]
        )
    }

    @Test("save, rename and delete a user look")
    func lifecycle() throws {
        let store = store()
        try store.save(look("Mine"))
        #expect(store.userLooks().map(\.name) == ["Mine"])
        try store.rename(from: "Mine", to: "Ours")
        #expect(store.hasUserLook("Ours"))
        try store.delete("Ours")
        #expect(store.userLooks().isEmpty)
    }

    @Test("a bundled name is reserved")
    func reservedNames() {
        let store = store()
        #expect(throws: LookStore.StoreError.reservedName("Glass")) {
            try store.save(look("Glass"))
        }
    }

    @Test("a restore drops built-ins, duplicates and foreign keys")
    func replaceFilters() throws {
        let store = store()
        var foreign = look("A")
        foreign.style["app_bar.content"] = .string("icon")
        let refused = try store.replaceUserLooks(
            with: [foreign, look("A"), look("Taskbar")]
        )
        #expect(refused == 2)
        #expect(store.userLooks().map(\.name) == ["A"])
        #expect(store.userLooks()[0].style["app_bar.content"] == nil)
    }

    @Test("export and import round-trip, foreign keys dropped")
    func roundTrip() throws {
        let store = store()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("look-\(UUID().uuidString).json")
        var exported = look("A")
        exported.colors["bogus"] = "#FFF"
        exported.style["app_bar.content"] = .string("icon")
        try store.export(LookExport(look: exported), to: url)
        let back = try store.importLook(from: url, palettes: [])
        #expect(back == look("A"))
    }

    @Test("a newer library refuses rather than reads empty")
    func newerFormatRefuses() throws {
        let store = store()
        try FileManager.default.createDirectory(
            at: store.url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(#"{"format": 99, "looks": []}"#.utf8).write(to: store.url)
        #expect(throws: LookStore.StoreError.unreadableLibrary) {
            try store.libraryLooks()
        }
    }
}
