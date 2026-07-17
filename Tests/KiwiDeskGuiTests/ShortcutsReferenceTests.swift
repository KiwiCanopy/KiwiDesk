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
        modeNames: [String] = [KeyMode.defaultName]
    ) -> ShortcutsReference {
        ShortcutsReferenceBuilder.build(
            mode: KeyMode(
                name: KeyMode.defaultName,
                bindings: bindings
            ),
            spaces: spaces,
            spaceIcons: [:],
            resizeStep: 50,
            modeNames: modeNames
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
        // Only the bound preset renders; the other three focus
        // directions have no binding and are absent.
        #expect(reference.apps.isEmpty)
        #expect(reference.custom.isEmpty)
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
        // Focus is the only non-empty subgroup; Move Windows /
        // Size & Float / Switch modes are gone.
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
}
