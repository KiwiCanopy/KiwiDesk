import Foundation
import SwiftUI
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// A navigation row observes nothing and is drawn `.equatable()`,
/// so a draft write that leaves it as it was skips it (#2783). That
/// is only safe while its equality moves with every value it draws,
/// so each case changes ONE input and asks whether two rows built
/// before and after compare apart — and an unrelated write, the
/// keystroke this exists for, must leave them equal. Main-actor
/// spend: one small model per case.
@Suite("A navigation row compares by what it draws", .serialized)
@MainActor
struct NavRowEqualityTests {
    private let focus = "KiwiDesk.focus(\"left\")"
    private let reload = "KiwiDesk.reload_config()"
    private var command: NavCommand {
        NavCommand(label: "Focus left", lua: focus)
    }

    /// Work is loaded and Home stored, so the row draws a reach;
    /// with no page to reach from it draws none.
    private func makeModel(reach: Bool = true) throws -> SettingsModel {
        let core = makeTestCore()
        var config = GuiConfig()
        config.spaces = [SpaceID("1")]
        config.layers = [
            KeyLayer(
                name: KeyLayer.defaultName,
                bindings: [
                    KeyBinding(combo: "alt+h", lua: focus, kind: .navigation),
                    KeyBinding(combo: "alt+r", lua: reload, kind: .custom),
                ]
            )
        ]
        try core.guiConfigStore.save(config)
        try core.profiles.save(profile("Work"))
        try core.profiles.write(profile("Home"))
        let model = makeTestModel(core: core)
        model.reload()
        if !reach { model.reachPage = nil }
        return model
    }

    private func profile(_ name: String) -> Profile {
        Profile(
            name: name,
            monitorSets: [MonitorSet(monitors: [])],
            spaces: [SpaceID("1")],
            spaceModes: [:],
            settings: TilingSettings()
        )
    }

    private func row(
        _ model: SettingsModel,
        _ command: NavCommand? = nil,
        layer: String = KeyLayer.defaultName
    ) -> NavRow {
        NavRow(
            model: model,
            bindings: Binding(
                get: { model.config.layers[0].bindings },
                set: { model.config.layers[0].bindings = $0 }
            ),
            command: command ?? self.command,
            layer: layer,
            disabled: []
        )
    }

    @Test("Another row's description leaves the row equal")
    func unrelatedWriteKeepsItEqual() throws {
        let model = try makeModel()
        let before = row(model)
        model.config.layers[0].bindings[1].desc = "Reload"
        model.config.layers[0].bindings[1].lua += " "
        #expect(row(model) == before)
    }

    @Test("Its own combo moves it")
    func ownComboMovesIt() throws {
        let model = try makeModel()
        let before = row(model)
        model.config.layers[0].bindings[0].combo = "alt+j"
        #expect(row(model) != before)
    }

    @Test("Another row taking its combo moves it")
    func conflictMovesIt() throws {
        let model = try makeModel()
        let before = row(model)
        model.config.layers[0].bindings[1].combo = "alt+h"
        #expect(row(model) != before)
    }

    @Test("A pick in its checklist moves it")
    func reachMovesIt() throws {
        let model = try makeModel()
        let before = row(model)
        let key = RuleReachTable<String>.keyID(
            layer: KeyLayer.defaultName,
            lua: focus
        )
        model.reachEdits.reach[.key, default: [:]][key] = .listed(["Work"])
        #expect(row(model) != before)
    }

    @Test("Its command going unavailable moves it")
    func unavailableMovesIt() throws {
        let model = try makeModel()
        var away = command
        away.unavailable = { "Not connected right now." }
        #expect(row(model, away) != row(model))
    }

    @Test("Its command's glyph moves it")
    func iconMovesIt() throws {
        let model = try makeModel()
        var star = command
        star.icon = "star"
        var moon = command
        moon.icon = "moon"
        #expect(row(model, star) != row(model, moon))
    }

    @Test("With no reach drawn, its combo and its conflict still move it")
    func bindingAndReadingMoveIt() throws {
        let model = try makeModel(reach: false)
        let before = row(model)
        #expect(before.drawn.reach == nil)
        model.config.layers[0].bindings[1].combo = "alt+h"
        let conflicted = row(model)
        #expect(conflicted.drawn.binding == before.drawn.binding)
        #expect(conflicted != before)
        model.config.layers[0].bindings[0].combo = "alt+j"
        #expect(row(model) != conflicted)
    }

    @Test("Its layer moves it")
    func layerMovesIt() throws {
        let model = try makeModel(reach: false)
        #expect(row(model, layer: "Gaming") != row(model))
    }
}
