import Foundation
import SwiftUI
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// A shortcut is named by its LOCALIZED row label wherever a
/// sentence or checklist names it (#2111, #96): the stored label is
/// an English identifier the reader never sees on the row itself.
@Suite("Binding name localization (#2111)", .serialized)
@MainActor
struct BindingNameLocalizationTests {
    private let stored = "Toggle display sticky"
    private let lua = "KiwiDesk.toggle_display_sticky()"

    @Test("the reach checklist names the row in the reader's language")
    func reachSubjectIsLocalized() {
        LocalizationManager.shared.select("de")
        defer { LocalizationManager.shared.select(nil) }
        let model = makeTestModel()
        let binding = KeyBinding(
            combo: "control+option+p",
            lua: lua,
            kind: .navigation,
            label: stored
        )
        let localized = KeybindingCatalog.localizedLabel(
            for: stored,
            config: model.config
        )
        // Vacuity: the row's own name differs from the stored one.
        #expect(localized != stored)
        let column = KeyReachColumn(
            model: model,
            layer: KeyLayer.defaultName,
            binding: binding
        )
        #expect(column.subject == localized)
    }

    @Test("the recorder's collision line names the holder localized")
    func rejectionHolderIsLocalized() throws {
        LocalizationManager.shared.select("de")
        defer { LocalizationManager.shared.select(nil) }
        let config = GuiConfig()
        let own = KeyBinding(combo: "", lua: "own()")
        let holder = KeyBinding(
            combo: "control+option+p",
            lua: lua,
            kind: .navigation,
            label: stored
        )
        var rows = [own, holder]
        let bindings = Binding<[KeyBinding]>(
            get: { rows },
            set: { rows = $0 }
        )
        let localized = KeybindingCatalog.localizedLabel(
            for: stored,
            config: config
        )
        #expect(localized != stored)
        let rejection = RecorderPreflight.rejection(
            combo: "control+option+p",
            excluding: { $0.id == own.id },
            bindings: bindings,
            config: config,
            commit: { _ in }
        )
        #expect(try #require(rejection).holder == localized)
    }
}
