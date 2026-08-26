import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The read-only shortcuts reference builder (#326): it filters the
/// `KeybindingCatalog` presets to bindings that actually exist,
/// routes each into its band, and — crucially — never drops a bound
/// shortcut (anything unrecognized falls through to Custom).
/// `.serialized` mirrors the other localization-touching suites
/// (`LocalizationManager` is a process-wide singleton).
@Suite("Shortcuts reference builder", .serialized)
@MainActor
struct ShortcutsReferenceTests {
    /// Pin English so the display-string assertions are
    /// deterministic regardless of the host's system language
    /// (`select(nil)` would follow the OS locale).
    private func reset() {
        LocalizationManager.shared.select("en")
    }

    private func binding(
        _ combo: String,
        _ lua: String,
        _ kind: KeyBinding.Kind
    ) -> KeyBinding {
        KeyBinding(combo: combo, lua: lua, kind: kind)
    }

    private func build(
        _ bindings: [KeyBinding],
        spaces: [SpaceID] = [SpaceID("1")],
        desktops: [Int] = [1, 2],
        layerNames: [String] = [KeyLayer.defaultName]
    ) -> ShortcutsReference {
        ShortcutsReferenceBuilder.build(
            layer: KeyLayer(
                name: KeyLayer.defaultName,
                bindings: bindings
            ),
            spaces: spaces,
            spaceIcons: [:],
            desktops: desktops,
            resizeStep: 50,
            layerNames: layerNames
        )
    }

    @Test("navigation rows land in the right subgroup, English")
    func navigationSubgroups() {
        reset()
        let reference = build([
            binding(
                "ctrl+left",
                "KiwiDesk.focus(\"left\")",
                .navigation
            )
        ])
        let focus = reference.controls.first {
            $0.title == "Focus"
        }
        #expect(focus?.rows.count == 1)
        #expect(focus?.rows.first?.label == "Focus window to the left")
        #expect(focus?.rows.first?.combo.isEmpty == false)
        // Compass directions carry a directional glyph (hybrid
        // symbol scheme); non-spatial commands stay label-only.
        #expect(focus?.rows.first?.icon == "arrow.left")
        // Only the bound preset renders; the other three focus
        // directions have no binding and are absent.
        #expect(reference.apps.isEmpty)
        #expect(reference.custom.isEmpty)
    }

    @Test("a space with no custom icon gets a numbered fallback")
    func spaceFallbackIcon() {
        reset()
        // Default spaces is ["1"], so bind the space-1 row.
        let reference = build([
            binding(
                "option+1",
                "KiwiDesk.focus_space(\"1\")",
                .navigation
            )
        ])
        let focus = reference.controls.first {
            $0.title == "Focus"
        }
        #expect(focus?.rows.first?.icon == "1.square")
    }

    @Test("a space named a direction word doesn't get an arrow")
    func spaceNamedDirectionNoArrow() {
        reset()
        // A space literally named "left" must get its space glyph,
        // not the directional arrow (substring false-match guard).
        let reference = build(
            [
                binding(
                    "option+0",
                    "KiwiDesk.focus_space(\"left\")",
                    .navigation
                )
            ],
            spaces: [SpaceID("left")]
        )
        let focus = reference.controls.first {
            $0.title == "Focus"
        }
        #expect(focus?.rows.first?.icon == "squares.below.rectangle")
    }

    @Test("empty bands are dropped, not rendered blank")
    func emptyBandsDropped() {
        reset()
        let reference = build([
            binding(
                "ctrl+left",
                "KiwiDesk.focus(\"left\")",
                .navigation
            )
        ])
        // Focus is the only non-empty subgroup; Move windows /
        // Size & float / Switch modes are gone.
        #expect(reference.controls.count == 1)
        #expect(reference.isEmpty == false)
    }

    @Test("application bindings render in the Apps band")
    func appsBand() {
        reset()
        let reference = build([
            binding(
                "cmd+1",
                "KiwiDesk.pull_or_spawn(\"com.apple.Safari\")",
                .application
            )
        ])
        #expect(reference.apps.count == 1)
        #expect(reference.controls.isEmpty)
        // A default open-or-focus row carries no behavior badge.
        #expect(reference.apps.first?.accessoryIcon == nil)
    }

    @Test("Open New app bindings carry a behavior badge (#334)")
    func openNewBadge() {
        reset()
        let reference = build([
            binding(
                "cmd+1",
                "KiwiDesk.pull_or_spawn(\"com.apple.safari\")",
                .application
            ),
            binding(
                "cmd+2",
                "KiwiDesk.spawn_new(\"com.apple.safari\")",
                .application
            ),
        ])
        // Both surface in the Apps band (spawn_new isn't dropped to
        // Custom); only the Open New row gets the badge.
        #expect(reference.apps.count == 2)
        let badged = reference.apps.filter {
            $0.accessoryIcon != nil
        }
        #expect(badged.count == 1)
        #expect(badged.first?.accessoryIcon == "macwindow.badge.plus")
        #expect(badged.first?.accessoryHelp.isEmpty == false)
    }

    @Test("custom Lua renders monospaced in the Custom band")
    func customBand() {
        reset()
        let reference = build([
            binding(
                "alt+r",
                "KiwiDesk.reload_config()",
                .custom
            )
        ])
        #expect(reference.custom.count == 1)
        #expect(reference.custom.first?.monospaced == true)
        #expect(
            reference.custom.first?.label
                == "KiwiDesk.reload_config()"
        )
    }

    @Test("an unrecognized navigation row is never invisible")
    func unrecognizedFallsToCustom() {
        reset()
        // A resize of a non-current step matches no step-50
        // preset, so it must still surface — in Custom, not
        // vanish.
        let reference = build([
            binding(
                "ctrl+equal",
                "KiwiDesk.resize(\"x\", 30)",
                .navigation
            )
        ])
        #expect(reference.controls.isEmpty)
        #expect(reference.custom.count == 1)
    }

    @Test("unrecorded bindings (empty combo) are skipped")
    func unrecordedSkipped() {
        reset()
        let reference = build([
            binding("", "KiwiDesk.focus(\"left\")", .navigation)
        ])
        #expect(reference.isEmpty)
    }

    @Test("a mode with nothing bound reports empty")
    func emptyMode() {
        reset()
        #expect(build([]).isEmpty)
    }

    @Test("a second combo for the same command is never invisible")
    func duplicateLuaSurfaces() {
        reset()
        // Two combos bound to the same nav command (vim keys +
        // arrows). Only one renders in Controls; the other must
        // still surface — in Custom, not vanish.
        let reference = build([
            binding(
                "ctrl+left",
                "KiwiDesk.focus(\"left\")",
                .navigation
            ),
            binding(
                "alt+h",
                "KiwiDesk.focus(\"left\")",
                .navigation
            ),
        ])
        let focus = reference.controls.first {
            $0.title == "Focus"
        }
        #expect(focus?.rows.count == 1)
        #expect(reference.custom.count == 1)
    }

    @Test("the active mode is excluded from Switch modes")
    func activeModeExcludedFromSwitch() {
        reset()
        // A self-switch row (switch to the mode you're in) must not
        // render — mirrors the editor's SwitchLayersGroup filter.
        let reference = build(
            [
                binding(
                    "alt+d",
                    "KiwiDesk.switch_layer(\"default\")",
                    .navigation
                )
            ],
            layerNames: [KeyLayer.defaultName, "Coding"]
        )
        let switchLayers = reference.controls.first {
            $0.title == "Switch modes"
        }
        // The only bound switch row targets the active mode, so the
        // subgroup is absent; the row falls through to Custom.
        #expect(switchLayers == nil)
        #expect(reference.custom.count == 1)
    }

    @Test("every catalog nav command lands in Controls, not Custom")
    func controlsCompleteness() {
        reset()
        let spaces = [SpaceID("1"), SpaceID("2")]
        let layerNames = [KeyLayer.defaultName, "Coding"]
        // Sourced from the same catalog membership the editor and the
        // import classifier use — so if buildControls ever drifts from
        // it, these commands fall to Custom and this test fails,
        // instead of the drift being silently absorbed.
        let commands =
            KeybindingCatalog.navigationGroups(spaces: spaces)
            .flatMap(\.commands)
            + KeybindingCatalog.resizeAndFloat(step: 50)
            + [KeybindingCatalog.switchLayerCommand("Coding")]
        let bindings = commands.map {
            KeyBinding(
                combo: "alt+z",
                lua: $0.lua,
                kind: .navigation
            )
        }
        let reference = build(
            bindings,
            spaces: spaces,
            layerNames: layerNames
        )
        #expect(reference.custom.isEmpty)
        let controlRows = reference.controls.reduce(0) {
            $0 + $1.rows.count
        }
        #expect(controlRows == commands.count)
    }
}
