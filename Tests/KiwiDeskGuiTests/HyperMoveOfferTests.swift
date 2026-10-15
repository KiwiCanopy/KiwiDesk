import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Hyper move offer in Settings (#1870): offered by direction,
/// named from the draft, staged into the draft like a recorded
/// chord, retired once accepted, and the dim of a Hyper row while
/// no key is set.
@Suite("Hyper move offer in Settings")
@MainActor
struct HyperMoveOfferTests {
    private func model(key: HyperSourceKey?) -> SettingsModel {
        let core = makeTestCore()
        core.setAppWide(persisting: false) { $0.hyperKey = key }
        let model = makeTestModel(core: core)
        var config = GuiConfig()
        config.spaces = [SpaceID(1)]
        config.layers = [
            KeyLayer(
                name: KeyLayer.defaultName,
                bindings: DefaultKeybindings.bindings(
                    spaces: config.spaces,
                    resizeStep: 50
                ) + [DefaultKeybindings.desktopRow(1)].compactMap { $0 }
            )
        ]
        model.config = config
        return model
    }

    private let floating = "KiwiDesk.toggle_floating()"

    @Test("a draft using Hyper keeps the card in Simple with no key")
    func presenceExpandsSimple() {
        #expect(!HyperKeyRow.isOffered(in: .simple, key: nil))
        #expect(
            HyperKeyRow.isOffered(in: .simple, key: nil, usesHyper: true)
        )
    }

    @Test("with a key set, the sheet lists the seed lines, named")
    func requestNamesTheLines() throws {
        LocalizationManager.shared.select("en")
        let model = model(key: .capsLock)
        #expect(model.hyperMoveDirection == .toHyper)
        let request = try #require(model.hyperMoveRequest())
        let line = try #require(request.lines.first { $0.id == floating })
        #expect(line.name == "Toggle floating")
        #expect(line.chords == "⌃⌥F → ✦F")
        #expect(line.ticked)
        #expect(request.lines.contains { $0.name.contains("KiwiHub") })
        #expect(request.desktop?.ticked == true)
        #expect(request.desktop?.name.contains("✦") == true)
    }

    @Test("Move stages into the draft, and the offer retires")
    func moveStagesAndRetires() throws {
        let model = model(key: .capsLock)
        let request = try #require(model.hyperMoveRequest())
        model.applyHyperMove(
            request,
            items: Set(request.lines.map(\.id)),
            desktop: true
        )
        let rows = model.config.layers[0].bindings
        #expect(rows.first { $0.lua == floating }?.combo == "hyper+f")
        #expect(model.config.desktopShortcutBase == .hyper)
        // Nothing reached the saved file: Save registers it.
        #expect(model.core.persistedGuiConfig()?.desktopShortcutBase != .hyper)
        #expect(model.hyperMoveOffer == nil)
        #expect(model.draftUsesHyper)
    }

    @Test("with no key, the offer runs the other way")
    func reverseWithNoKey() throws {
        let model = model(key: .capsLock)
        let request = try #require(model.hyperMoveRequest())
        let ids = Set(request.lines.map(\.id))
        model.applyHyperMove(request, items: ids, desktop: true)
        model.core.setAppWide(persisting: false) { $0.hyperKey = nil }
        #expect(model.hyperMoveDirection == .back)
        let back = try #require(model.hyperMoveRequest())
        #expect(Set(back.lines.map(\.id)) == ids)
        model.applyHyperMove(back, items: ids, desktop: true)
        #expect(model.config.desktopShortcutBase == .standard)
        #expect(!model.draftUsesHyper)
        #expect(model.hyperMoveOffer == nil)
    }

    /// The surfacing branches only a scan sees (gui.md): the offer
    /// row, the section's sheet and dim, and the recorder's dim.
    @Test("the offer, the sheet and the dim are wired")
    func wiring() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings")
        func source(_ path: String) throws -> String {
            SourceScan.stripComments(
                try String(
                    contentsOf: root.appendingPathComponent(path),
                    encoding: .utf8
                )
            )
        }
        let row = try source(
            "Components/Keybindings/HyperKeyRow.swift"
        )
        #expect(row.contains("if model.hyperMoveOffer != nil"))
        #expect(row.contains("usesHyper: model.draftUsesHyper"))
        // A stored-profile page greys the offer and says why.
        #expect(row.contains(".disabled(offerReason != nil)"))
        #expect(
            row.contains("editingStoredProfile: model.editingStoredProfile")
        )
        #expect(row.contains("return HyperMoveWords.storedPage"))
        #expect(row.contains("? HyperMoveWords.offCaption : nil"))
        // With no key, the reverse offer says why rows are dim.
        #expect(row.contains("if let text = offerCaption { caption(text) }"))
        let sheet = try source(
            "Components/Keybindings/HyperMoveSheet.swift"
        )
        // Every sheet text but the title (no ✦) speaks ✦ as Hyper.
        #expect(sheet.occurrences(of: "Text(") == 2)
        #expect(sheet.contains("accessibilityLabel(HyperMoveWords.spoken("))
        let section = try source("Sections/ShortcutsSection.swift")
        #expect(
            section.contains(
                ".environment(\\.hyperKeyIsOff, model.appWide.hyperKey == nil)"
            )
        )
        #expect(section.contains("model.applyHyperMove("))
        let field = try source(
            "Components/Keybindings/Recorder/KeyRecorderField.swift"
        )
        #expect(field.contains(".opacity(hyperDormant ?"))
        #expect(field.contains("hyperKeyIsOff && !recording"))
    }
}
