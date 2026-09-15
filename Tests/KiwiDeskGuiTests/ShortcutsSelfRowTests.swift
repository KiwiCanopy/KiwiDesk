import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The panel never lists its own opener (#602 fallout): every
/// `KiwiDesk.show_shortcuts()` binding is dropped from the
/// builder's working set before any band builds, because the
/// footer's dismiss hint already teaches that combo wherever the
/// bindings are live. Without the suppression it leaks into
/// Custom as raw Lua — the band that means "user-authored".
/// `.serialized` mirrors the sibling suite
/// (`LocalizationManager` is a process-wide singleton).
@Suite("Shortcuts reference self-row suppression", .serialized)
@MainActor
struct ShortcutsSelfRowTests {
    private func reset() {
        LocalizationManager.shared.select("en")
    }

    private func build(
        _ bindings: [KeyBinding]
    ) -> ShortcutsReference {
        ShortcutsReferenceBuilder.build(
            layer: KeyLayer(
                name: KeyLayer.defaultName,
                bindings: bindings
            ),
            spaces: [SpaceID("1")],
            spaceIcons: [:],
            desktops: [1, 2],
            resizeStep: 50,
            layerNames: [KeyLayer.defaultName]
        )
    }

    @Test("a mode holding only the seeded opener reports empty")
    func seededOpenerOnlyIsEmpty() {
        reset()
        // Pre-fix, the whole panel was one raw-Lua Custom row.
        // The honest render is the "nothing bound" placeholder;
        // the footer still shows the combo.
        let reference = build([
            DefaultKeybindings.showShortcutsRow()
        ])
        #expect(reference.isEmpty)
    }

    /// The rows `LayerStripEditor.addLayer` seeds a fresh layer
    /// with (#1381): the opener is dropped, the Settings row
    /// stays — so a fresh layer's panel is no longer empty.
    @Test("a fresh layer shows Open Settings and not the opener")
    func freshLayerShowsSettingsOnly() {
        reset()
        let reference = build(DefaultKeybindings.appChromeRows())
        #expect(!reference.isEmpty)
        let rows = reference.controls.flatMap(\.rows)
        #expect(rows.count == 1)
        #expect(reference.custom.isEmpty)
        #expect(
            rows.first?.label
                == KeybindingCatalog.openSettings.resolvedLabel
        )
    }

    @Test("a second combo for the opener can't leak to Custom")
    func rebindTwinStaysSuppressed() {
        reset()
        // Two combos on the same command normally surface the
        // twin in Custom (never-invisible contract); the opener
        // is the deliberate exception — both are dropped. The
        // twin is `.custom`-kinded on purpose: a user-typed row
        // is the likeliest real twin, and the suppression must
        // be kind-agnostic (it once gated only the Custom
        // fallthrough, which an `.application` kind bypassed).
        let reference = build([
            DefaultKeybindings.showShortcutsRow(),
            KeyBinding(
                combo: "control+option+h",
                lua: ShortcutsOpenBinding.lua,
                kind: .custom
            ),
        ])
        #expect(reference.isEmpty)
    }

    @Test("suppression consumes nothing beside the opener")
    func otherBindingsUntouched() {
        reset()
        let reference = build([
            DefaultKeybindings.showShortcutsRow(),
            KeyBinding(
                combo: "ctrl+left",
                lua: "KiwiDesk.focus(\"left\")",
                kind: .navigation
            ),
            KeyBinding(
                combo: "alt+r",
                lua: "KiwiDesk.reload_config()",
                kind: .custom
            ),
        ])
        let focus = reference.controls.first {
            $0.title == "Focus"
        }
        #expect(focus?.rows.count == 1)
        #expect(reference.custom.count == 1)
        #expect(
            reference.custom.first?.label
                == "KiwiDesk.reload_config()"
        )
    }
}
