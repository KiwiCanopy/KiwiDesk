import Foundation
import Testing

@testable import KiwiDeskCore

/// The look library, `looks.json` (#1684): the palette store's
/// invariants, plus a palette rename re-pointing its looks and an
/// export that carries a user palette's colours.
@Suite("Look store")
struct LookStoreTests {
    private func store() -> LookStore {
        LookStore(
            directory: FileManager.default.temporaryDirectory
                .appendingPathComponent("looks-\(UUID().uuidString)")
        )
    }

    private func look(
        _ name: String,
        palette: String? = "Slate"
    ) -> ShelfLook {
        ShelfLook(
            name: name,
            palette: palette,
            style: ["kiwishelf.thickness": .number(30)]
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

    @Test("a palette rename re-points only its looks")
    func repoint() throws {
        let store = store()
        try store.save(look("A", palette: "Old"))
        try store.save(look("B", palette: "Slate"))
        try store.repointPalette(from: "Old", to: "New")
        #expect(store.userLooks().map(\.palette) == ["New", "Slate"])
    }

    @Test("export and import round-trip with the palette")
    func roundTrip() throws {
        let store = store()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("look-\(UUID().uuidString).json")
        let palette = ColorPalette(
            name: "Mine",
            colors: ["kiwishelf.fill_color": "#112233", "bogus": "#FFF"]
        )
        try store.export(
            LookExport(look: look("A", palette: "Mine"), palette: palette),
            to: url
        )
        let back = try store.importLook(from: url)
        #expect(back.look == look("A", palette: "Mine"))
        #expect(back.palette?.colors == ["kiwishelf.fill_color": "#112233"])
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
