import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// A layer's icon reaches its switch rows and its chip (#3267 ▸
/// Ruling 1, 3): Settings from the draft, KiwiHub from the layers
/// it reads, both through `ShortcutsReferenceBuilder.icon(for:)`,
/// the layers symbol where none is set.
@Suite("Layer icon wiring (#3267)")
@MainActor
struct LayerIconWiringTests {
    private static let root = SourceScan.repoRoot(from: #filePath)
    private static let generic = ShortcutGlyph.symbol("square.3.layers.3d")

    private func switchGlyph(
        to name: String,
        in rows: [NavCommand]
    ) -> ShortcutGlyph? {
        let lua = KeybindingCatalog.switchLayerCommand(name).lua
        return rows.first { $0.lua == lua }
            .flatMap(ShortcutsReferenceBuilder.icon(for:))
    }

    @Test("a Settings switch row wears the draft layer's icon")
    func settingsRowsReadTheDraft() throws {
        let model = makeTestModel()
        model.config.layers += [
            KeyLayer(name: "Gaming", icon: "🎮"),
            KeyLayer(name: "Mouse", icon: "computermouse"),
            KeyLayer(name: "Plain"),
        ]
        let rows =
            ShortcutsFamilyRows.ofDraft(model, layer: KeyLayer.defaultName)
            .rows(for: .shortcuts(.switchToLayer)) ?? []
        #expect(switchGlyph(to: "Gaming", in: rows) == .emoji("🎮"))
        #expect(
            switchGlyph(to: "Mouse", in: rows) == .symbol("computermouse")
        )
        #expect(switchGlyph(to: "Plain", in: rows) == Self.generic)
        // A draft edit shows at once: the next build reads it.
        let gaming = try #require(
            model.config.layers.firstIndex { $0.name == "Gaming" }
        )
        model.config.layers[gaming].icon = "🕹️"
        let edited =
            ShortcutsFamilyRows.ofDraft(model, layer: KeyLayer.defaultName)
            .rows(for: .shortcuts(.switchToLayer)) ?? []
        #expect(switchGlyph(to: "Gaming", in: edited) == .emoji("🕹️"))
    }

    @Test("a KiwiHub switch row wears the layer's icon")
    func panelRowsReadTheIcons() {
        let layers = [
            KeyLayer(
                name: KeyLayer.defaultName,
                bindings: [
                    KeyBinding(
                        combo: "ctrl+alt+g",
                        lua: KeybindingCatalog.switchLayerCommand(
                            "Gaming"
                        ).lua,
                        kind: .navigation,
                        label: ""
                    )
                ]
            ),
            KeyLayer(name: "Gaming", icon: "🎮"),
        ]
        let reference = ShortcutsReferenceBuilder.build(
            layer: layers[0],
            spaces: [],
            spaceIcons: [:],
            desktops: [],
            resizeStep: 50,
            layerNames: layers.map(\.name),
            layerIcons: KeyLayer.icons(of: layers)
        )
        let lua = KeybindingCatalog.switchLayerCommand("Gaming").lua
        let row = reference.controls.flatMap(\.rows).first { $0.id == lua }
        #expect(row?.icon == .emoji("🎮"))
    }

    @Test("the panel hands the builder its layers' icons")
    func panelPassesTheIcons() throws {
        let source = try SourceScan.strippedSource(
            at: Self.root.appendingPathComponent(
                "Sources/KiwiDesk/Jump/JumpPanelController+Shortcuts.swift"
            )
        )
        let flat = source.filter { !$0.isWhitespace }
        #expect(flat.contains("layerIcons:KeyLayer.icons(of:layers)"))
    }

    @Test("the icons map skips default and unset icons")
    func iconsMap() {
        let icons = KeyLayer.icons(of: [
            KeyLayer(name: KeyLayer.defaultName, icon: "house"),
            KeyLayer(name: "A", icon: "star"),
            KeyLayer(name: "B", icon: ""),
            KeyLayer(name: "C"),
        ])
        #expect(icons == ["A": "star"])
    }

    @Test("a chip reads the draft icon through the rows' one map")
    func chipReadsTheDraft() throws {
        let source = try SourceScan.strippedSource(
            at: Self.root.appendingPathComponent(
                "Sources/KiwiDesk/Settings/Sections/LayerStripEditor.swift"
            )
        )
        let flat = source.filter { !$0.isWhitespace }
        #expect(flat.contains("icon:chipIcon(name),"))
        #expect(
            flat.contains(
                "ShortcutGlyph(icon:KeyLayer.icons(of:model.config.layers)"
                    + "[name])"
            )
        )
    }
}
