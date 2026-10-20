import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The Desktop tier seen from Settings: the seed's row is the
/// catalog's own Go to Desktop row, so the GUI recognises it, and
/// an open draft takes a top-up's rows rather than saving over
/// them.
@Suite("Settings takes the Desktop tier's rows", .serialized)
@MainActor
struct DesktopShortcutDraftTests {
    @Test("The seed's row is the catalog's Go to Desktop row")
    func seedMatchesTheCatalog() throws {
        for number in 1...DefaultKeybindings.digitCapacity {
            let row = try #require(
                DefaultKeybindings.desktopRow(number, base: .standard)
            )
            let catalog = try #require(
                KeybindingCatalog.goToDesktop([number]).first
            )
            #expect(row.lua == catalog.lua)
            #expect(row.label == catalog.label)
            #expect(KeybindingCatalog.desktopNumber(from: row.lua) == number)
            #expect(DefaultKeybindings.isDesktopRow(row))
        }
    }

    @Test("A dirty draft keeps the rows a top-up added")
    func dirtyDraftAdoptsTheRows() throws {
        let core = makeTestCore()
        try core.guiConfigStore.save(GuiConfig())
        let model = makeTestModel(core: core)
        model.reload()
        model.config.floatRules.append("com.example.dirty")
        #expect(model.isDirty)
        let row = try #require(
            DefaultKeybindings.desktopRow(4, base: .standard)
        )
        model.adoptShortcutAdd([row])
        let base = { (layers: [KeyLayer]) in
            layers.first { $0.isDefault }?.bindings.map(\.lua) ?? []
        }
        #expect(base(model.config.layers).contains(row.lua))
        #expect(base(model.cleanConfig.layers).contains(row.lua))
        // Only the user's own edit is pending, not the top-up's.
        #expect(model.isDirty)
        model.config.floatRules.removeAll { $0 == "com.example.dirty" }
        #expect(!model.isDirty)
    }
}
