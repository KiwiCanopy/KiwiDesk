import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Home cards' answers (#678 turn 9): the subtitles derive
/// from the draft, not from constants — a card is an answer,
/// and an answer must move when the data does. Asserted on the
/// derivations through a real model over the test core.
@MainActor
@Suite("Home card content")
struct HomeCardContentTests {
    private func model() -> SettingsModel {
        makeTestModel()
    }

    @Test("the spaces answer counts spaces and distinct modes")
    func spacesAnswer() {
        let model = model()
        model.config.spaces = ["a", "b", "c"]
        model.config.spaceModes = [
            "a": .grid, "b": .grid, "c": .monocle,
        ]
        let line = HomeCardContent.subtitle(
            for: .spaces,
            model: model
        )
        #expect(line.contains("3"))
        #expect(line.contains("2"))
        // The unassigned space inherits the list's own `.bsp`
        // default, so an explicit bsp elsewhere collapses into
        // it rather than counting a third mode.
        model.config.spaceModes = ["a": .bsp, "b": .monocle]
        let defaulted = HomeCardContent.subtitle(
            for: .spaces,
            model: model
        )
        #expect(defaulted.contains("2"))
    }

    @Test("the gaps answer reads the draft's own numbers")
    func gapsAnswer() {
        let model = model()
        model.config.settings.gapsGlobal.outer.top = 14
        model.config.settings.gapsGlobal.inner.horizontal = 7
        model.config.settings.borderStyle.width = 3
        model.config.settings.borderStyle.enabled = true
        let line = HomeCardContent.subtitle(
            for: .gapsAndBorders,
            model: model
        )
        #expect(line.contains("14"))
        #expect(line.contains("7"))
        #expect(line.contains("3"))
        // Order, not just presence: with distinct values in
        // every slot, `contains` alone passes with the outer
        // and inner arguments swapped (guard-prover proved the
        // swap green, 2026-08-04). The English frame is
        // "Outer … · inner …", so outer's value must render
        // first.
        let outerAt = line.range(of: "14")
        let innerAt = line.range(of: "7")
        #expect(outerAt != nil && innerAt != nil)
        if let outerAt, let innerAt {
            #expect(
                outerAt.lowerBound < innerAt.lowerBound,
                "outer and inner render swapped"
            )
        }
        // Border off swaps the frame, not just a number.
        model.config.settings.borderStyle.enabled = false
        let off = HomeCardContent.subtitle(
            for: .gapsAndBorders,
            model: model
        )
        #expect(!off.contains("3 pt"))
    }

    @Test("the shortcuts answer counts default-layer bindings")
    func shortcutsAnswer() {
        let model = model()
        var layer = KeyLayer.defaultLayer
        layer.bindings = [
            KeyBinding(
                combo: "alt+h",
                lua: "kiwi.focus('left')",
                kind: .navigation,
                label: "Focus left"
            ),
            KeyBinding(
                combo: "alt+l",
                lua: "kiwi.focus('right')",
                kind: .navigation,
                label: "Focus right"
            ),
        ]
        // A second, non-default layer with its own binding: the
        // count is the DEFAULT layer's, so an all-layers sum
        // would read 3 here (guard-prover found the one-layer
        // fixture blind to exactly that).
        var resize = KeyLayer.defaultLayer
        resize.name = "resize"
        resize.bindings = [
            KeyBinding(
                combo: "alt+r",
                lua: "kiwi.grow('width')",
                kind: .navigation,
                label: "Grow"
            )
        ]
        model.config.layers = [layer, resize]
        let line = HomeCardContent.subtitle(
            for: .shortcuts,
            model: model
        )
        #expect(line.contains("2"))
        #expect(!line.contains("3"))
    }

    @Test("the conflict shout appears only with conflicts")
    func conflictShout() {
        let model = model()
        var layer = KeyLayer.defaultLayer
        layer.bindings = [
            KeyBinding(
                combo: "alt+h",
                lua: "kiwi.focus('left')",
                kind: .navigation,
                label: "Focus left"
            )
        ]
        model.config.layers = [layer]
        #expect(
            HomeCardContent.conflictShout(
                for: .shortcuts,
                model: model
            ) == nil
        )
        layer.bindings.append(
            KeyBinding(
                combo: "alt+h",
                lua: "kiwi.focus('right')",
                kind: .navigation,
                label: "Focus right"
            )
        )
        model.config.layers = [layer]
        let shout = HomeCardContent.conflictShout(
            for: .shortcuts,
            model: model
        )
        #expect(shout != nil)
        // Only Shortcuts may shout — the card grid's one
        // permitted alarm surface.
        #expect(
            HomeCardContent.conflictShout(
                for: .bars,
                model: model
            ) == nil
        )
    }

    @Test("the app-rules answer covers pins and floats")
    func appRulesAnswer() {
        let model = model()
        model.config.appRules = ["Safari": "web"]
        model.config.floatRules = ["Info", "Copy"]
        let line = HomeCardContent.subtitle(
            for: .appRules,
            model: model
        )
        #expect(line.contains("3"))
        model.config.appRules = [:]
        model.config.floatRules = []
        let none = HomeCardContent.subtitle(
            for: .appRules,
            model: model
        )
        #expect(!none.contains("0"))
    }

    /// The Advanced Colours count is the census's, so the card
    /// can never disagree with the area it opens.
    @Test("the colour count is the census's own")
    func advancedColourCount() {
        let expected = SettingKey.allCases.filter {
            $0.placement.area == .advancedColours
                && [.atRest, .showMore].contains(
                    $0.placement.tier
                )
        }.count
        let line = HomeCardContent.subtitle(
            for: .advancedColors,
            model: model()
        )
        #expect(line.contains("\(expected)"))
    }
}
