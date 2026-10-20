import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The switch on a page other profiles share (#2460): the moved
/// shared rows reach every profile that inherits them yet read as
/// the switch's one row, the shared base Save writes is moved with
/// every profile's tombstone, and the rows it cannot reach — another
/// profile's own — are listed.
@Suite("Shortcut base switch across profiles (#2460)", .serialized)
@MainActor
struct ShortcutBaseReachTests {
    private let floating = "KiwiDesk.toggle_floating()"
    private let sticky = "KiwiDesk.toggle_sticky()"

    private func row(_ combo: String, _ lua: String) -> KeyBinding {
        KeyBinding(combo: combo, lua: lua, kind: .navigation, label: "")
    }

    /// Work is loaded and edited; Home and Away follow the base,
    /// `overrides` giving a profile rows of its own.
    private func model(
        overrides: [String: KeyLayerOverride] = [:],
        on base: ShortcutBase = .standard
    ) throws -> SettingsModel {
        let core = makeTestCore()
        let mod = base == .hyper ? "hyper+" : "control+option+"
        var config = GuiConfig()
        config.spaces = [SpaceID("1")]
        config.shortcutBase = base
        config.layers = [
            KeyLayer(
                name: KeyLayer.defaultName,
                bindings: [row(mod + "f", floating), row(mod + "s", sticky)]
            ),
            KeyLayer(name: "work", bindings: [row(mod + "w", "w()")]),
        ]
        try core.guiConfigStore.save(config)
        try core.profiles.save(profile("Work", overrides["Work"]))
        for name in ["Home", "Away"] {
            try core.profiles.write(profile(name, overrides[name]))
        }
        let model = makeTestModel(core: core)
        model.reload()
        return model
    }

    private func profile(
        _ name: String,
        _ layers: KeyLayerOverride?
    ) -> Profile {
        Profile(
            name: name,
            monitorSets: [MonitorSet(monitors: [])],
            spaces: [SpaceID("1")],
            spaceModes: [:],
            settings: TilingSettings(),
            layers: layers
        )
    }

    @Test("the pill reads one row while other profiles inherit")
    func pillHasOneRow() throws {
        LocalizationManager.shared.select("en")
        let model = try model()
        model.setShortcutBase(.hyper)
        // Vacuity: the moved rows reached the other profiles.
        #expect(
            model.encodedReach?.keyBase.first?.bindings.map(\.combo)
                == ["hyper+f", "hyper+s"]
        )
        #expect(model.rowsLeftOnStandard.isEmpty)
        let rows = SettingsDiffRowSource.rows(for: model)
        #expect(
            rows.filter { $0.key == .shortcuts(.shortcutBase) }.count == 1
        )
        #expect(!rows.contains { $0.key == .shortcuts(.layers) })
    }

    @Test("Save writes the shared base moved")
    func sidecarIsMoved() throws {
        let model = try model()
        model.setShortcutBase(.hyper)
        let sidecar = model.sidecarConfig
        #expect(sidecar.shortcutBase == .hyper)
        #expect(
            sidecar.layers.first?.bindings.map(\.combo)
                == ["hyper+f", "hyper+s"]
        )
    }

    @Test("another profile's own row is listed, the page's is not")
    func otherProfileRowIsListed() throws {
        let own = KeyLayerOverride(
            layers: [
                KeyLayer(
                    name: KeyLayer.defaultName,
                    bindings: [row("control+option+y", "hs.x()")]
                )
            ]
        )
        let model = try model(overrides: ["Work": own, "Home": own])
        model.setShortcutBase(.hyper)
        let reasons = model.rowsLeftOnStandard.map(\.reason)
        #expect(reasons == [.profile("Home")])
    }

    /// `name`'s resolved default layer, read back from the files.
    private func savedDefault(
        _ model: SettingsModel,
        _ name: String
    ) throws -> [KeyBinding] {
        let base = try #require(model.core.guiConfigStore.load()).layers
        let profile = try model.core.profiles.read(name: name)
        let layers = profile.layers?.resolved(onto: base) ?? base
        return layers.first { $0.name == KeyLayer.defaultName }?.bindings
            ?? []
    }

    /// The owner's ruling (2026-10-20): a row a profile leaves out
    /// moves with the rest, and its tombstone with it, so it stays
    /// out there and reaches every other profile on `✦`.
    @Test("a row the page's profile leaves out moves, still left out")
    func leftOutRowMovesWithItsTombstone() throws {
        let leaves = KeyLayerOverride(
            removed: [KeyLayer.defaultName: ["control+option+s"]]
        )
        let model = try model(overrides: ["Work": leaves])
        model.setShortcutBase(.hyper)
        #expect(model.rowsLeftOnStandard.isEmpty)
        #expect(model.saveRuleReach() == .landed)
        #expect(
            try savedDefault(model, "Work").map(\.combo) == ["hyper+f"]
        )
        #expect(
            try savedDefault(model, "Home").map(\.combo)
                == ["hyper+f", "hyper+s"]
        )
        #expect(
            try model.core.profiles.read(name: "Work").layers?.removed
                == [KeyLayer.defaultName: ["hyper+s"]]
        )
    }

    /// A row the page keeps on its old chord — its target held by
    /// the page's own row — stays there in the shared keymap too, so
    /// the page and the files never disagree about where it is.
    @Test("a row the page keeps stays put for every profile")
    func pageKeptRowStays() throws {
        let holds = KeyLayerOverride(
            layers: [
                KeyLayer(
                    name: KeyLayer.defaultName,
                    bindings: [row("hyper+f", "hs.x()")]
                )
            ]
        )
        let model = try model(overrides: ["Work": holds])
        model.setShortcutBase(.hyper)
        #expect(model.saveRuleReach() == .landed)
        #expect(
            try savedDefault(model, "Home").first { $0.lua == floating }?
                .combo == "control+option+f"
        )
    }

    /// A switch that moves no row the page draws still moves the
    /// shared keymap, and the memo must not serve the old one.
    @Test("a switch moving only hidden rows refreshes the reach memo")
    func hiddenOnlySwitchRefreshesTheMemo() throws {
        let leaves = KeyLayerOverride(
            removed: [
                KeyLayer.defaultName: [
                    "control+option+f", "control+option+s",
                ]
            ],
            leftOut: ["work"]
        )
        let model = try model(overrides: ["Work": leaves])
        let before = model.encodedReach?.keyBase.first?.bindings
        model.setShortcutBase(.hyper)
        #expect(before?.map(\.combo).first == "control+option+f")
        #expect(
            model.encodedReach?.keyBase.first?.bindings.map(\.combo)
                == ["hyper+f", "hyper+s"]
        )
    }

    /// The way back moves the tombstone back with the row.
    @Test("the way back to ⌃⌥ keeps a left-out row out")
    func reverseSwitchKeepsItOut() throws {
        let leaves = KeyLayerOverride(
            removed: [KeyLayer.defaultName: ["hyper+s"]]
        )
        let model = try model(overrides: ["Work": leaves], on: .hyper)
        model.setShortcutBase(.standard)
        #expect(model.saveRuleReach() == .landed)
        #expect(
            try savedDefault(model, "Work").map(\.combo)
                == ["control+option+f"]
        )
        #expect(
            try savedDefault(model, "Home").map(\.combo)
                == ["control+option+f", "control+option+s"]
        )
    }

    /// Another profile's tombstone follows a row the page shows.
    @Test("another profile's left-out row stays out there")
    func otherProfileTombstoneFollows() throws {
        let leaves = KeyLayerOverride(
            removed: [KeyLayer.defaultName: ["control+option+f"]]
        )
        let model = try model(overrides: ["Home": leaves])
        model.setShortcutBase(.hyper)
        #expect(model.saveRuleReach() == .landed)
        #expect(
            try savedDefault(model, "Home").map(\.lua) == [sticky]
        )
        #expect(
            try savedDefault(model, "Away").map(\.combo)
                == ["hyper+f", "hyper+s"]
        )
    }

    /// A profile that rebound a shared row's chord to its own action
    /// went without that row; it still does once the row moves.
    @Test("a profile's own row on a moved chord keeps the row out")
    func replacedRowStaysOut() throws {
        let rebinds = KeyLayerOverride(
            layers: [
                KeyLayer(
                    name: KeyLayer.defaultName,
                    bindings: [row("control+option+f", "hs.x()")]
                )
            ]
        )
        let model = try model(overrides: ["Home": rebinds])
        model.setShortcutBase(.hyper)
        #expect(model.saveRuleReach() == .landed)
        let home = try savedDefault(model, "Home")
        #expect(!home.contains { $0.lua == floating })
        #expect(home.contains { $0.combo == "control+option+f" })
    }

    /// A whole layer left out is a mark on the layer's name, which
    /// the move leaves alone: the layer moves for everyone else.
    @Test("a shared layer the page's profile leaves out moves")
    func leftOutLayerMoves() throws {
        let leaves = KeyLayerOverride(leftOut: ["work"])
        let model = try model(overrides: ["Work": leaves])
        model.setShortcutBase(.hyper)
        #expect(model.rowsLeftOnStandard.isEmpty)
        #expect(model.saveRuleReach() == .landed)
        let base = try #require(model.core.guiConfigStore.load()).layers
        #expect(
            base.first { $0.name == "work" }?.bindings.map(\.combo)
                == ["hyper+w"]
        )
        #expect(
            try model.core.profiles.read(name: "Work").layers?.leftOut
                == ["work"]
        )
    }

    /// The tombstones the switch moved narrate as its one row.
    @Test("the pill reads one row when tombstones move")
    func pillHasOneRowWithTombstones() throws {
        LocalizationManager.shared.select("en")
        let leaves = KeyLayerOverride(
            removed: [KeyLayer.defaultName: ["control+option+s"]]
        )
        let model = try model(overrides: ["Work": leaves, "Home": leaves])
        model.setShortcutBase(.hyper)
        let rows = SettingsDiffRowSource.rows(for: model)
        #expect(
            rows.filter { $0.key == .shortcuts(.shortcutBase) }.count == 1
        )
        #expect(!rows.contains { $0.key == .shortcuts(.layers) })
    }

    /// The draft's own edits are in the base Save writes: a layer
    /// renamed or a shared row deleted is never "left out".
    @Test("a draft's rename or delete is not read as left out")
    func draftEditsAreNotLeftOut() throws {
        let model = try model()
        model.renameLayer("work", to: "office")
        model.config.layers[0].bindings.removeAll { $0.lua == sticky }
        model.setShortcutBase(.hyper)
        #expect(model.rowsLeftOnStandard.isEmpty)
    }
}
