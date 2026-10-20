import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The switch on a page other profiles share (#2460): the moved
/// shared rows reach every profile that inherits them yet read as
/// the switch's one row, the shared base Save writes is moved, and
/// the rows it cannot reach are listed — another profile's own, and
/// a shared row the page's profile leaves out.
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
        overrides: [String: KeyLayerOverride] = [:]
    ) throws -> SettingsModel {
        let core = makeTestCore()
        var config = GuiConfig()
        config.spaces = [SpaceID("1")]
        config.layers = [
            KeyLayer(
                name: KeyLayer.defaultName,
                bindings: [
                    row("control+option+f", floating),
                    row("control+option+s", sticky),
                ]
            )
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

    @Test("a shared row the page's profile leaves out is listed")
    func leftOutRowIsListed() throws {
        let leaves = KeyLayerOverride(
            removed: [KeyLayer.defaultName: ["control+option+s"]]
        )
        let model = try model(overrides: ["Work": leaves])
        model.setShortcutBase(.hyper)
        let left = model.rowsLeftOnStandard
        #expect(left.map(\.reason) == [.leftOutHere])
        #expect(left.first?.row.lua == sticky)
    }
}
