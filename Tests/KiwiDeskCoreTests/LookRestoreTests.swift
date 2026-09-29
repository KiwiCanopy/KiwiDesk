import Foundation
import Testing

@testable import KiwiDeskCore

/// Looks in a backup (#1684): a bundle carrying looks replaces the
/// library; one written before looks travelled leaves it alone.
@Suite("Look backup restore")
@MainActor
struct LookRestoreTests {
    private let hardDelete: (URL) throws -> Void = {
        try FileManager.default.removeItem(at: $0)
    }

    private func look(_ name: String) -> ShelfLook {
        ShelfLook(
            name: name,
            style: ["kiwishelf.thickness": .number(30)],
            colors: [:]
        )
    }

    private func bundle(looks: [ShelfLook]?) -> SetupBundle {
        SetupBundle(
            writtenBy: "test",
            config: nil,
            profiles: [],
            palettes: [ColorPalette(name: "P", colors: [:])],
            looks: looks
        )
    }

    @Test("a bundle's looks replace the library")
    func replaces() throws {
        let core = makeTestCore()
        try core.lookLibrary.save(look("Here"))
        try core.restoreSetup(
            from: bundle(looks: [look("There")]),
            trash: hardDelete
        )
        #expect(core.lookLibrary.userLooks().map(\.name) == ["There"])
    }

    @Test("an older bundle, without looks, leaves them alone")
    func olderBundleKeeps() throws {
        let core = makeTestCore()
        try core.lookLibrary.save(look("Here"))
        try core.restoreSetup(from: bundle(looks: nil), trash: hardDelete)
        #expect(core.lookLibrary.userLooks().map(\.name) == ["Here"])
    }

    @Test("an empty looks list replaces the library with none")
    func emptyReplaces() throws {
        let core = makeTestCore()
        try core.lookLibrary.save(look("Here"))
        try core.restoreSetup(from: bundle(looks: []), trash: hardDelete)
        #expect(core.lookLibrary.userLooks().isEmpty)
    }

    @Test("an exported backup reads back with its looks")
    func roundTrip() throws {
        let core = makeTestCore()
        try core.lookLibrary.save(look("Mine"))
        let url = core.configDirectory.appendingPathComponent("b.json")
        try core.writeBackup(to: url)
        let read = try core.readBackup(at: url)
        #expect(read.looks?.map(\.name) == ["Mine"])
    }
}
