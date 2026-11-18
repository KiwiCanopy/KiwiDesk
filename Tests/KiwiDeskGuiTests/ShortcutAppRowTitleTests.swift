import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// KiwiHub's Apps rows say their action in words (#3448 ▸ Ruling):
/// the title names gather or open-new, no badge, the rows still sort
/// by the app's name, and the App Font glyph is looked up by that
/// name, never by the title.
@Suite("Shortcuts ▸ Apps row titles (#3448)", .serialized)
@MainActor
struct ShortcutAppRowTitleTests {
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

    private func build(_ bindings: [KeyBinding]) -> ShortcutsReference {
        ShortcutsReferenceBuilder.build(
            layer: KeyLayer(name: KeyLayer.defaultName, bindings: bindings),
            spaces: [],
            spaceIcons: [:],
            desktops: [],
            resizeStep: 50,
            layerNames: [KeyLayer.defaultName]
        )
    }

    @Test("an app row says its action in its title, no badge (#3448)")
    func appRowTitlesSayTheAction() {
        reset()
        // No installed app answers these ids, so each name is its id
        // and the order below holds on every host: by name `h` leads
        // `m`; by title "Gather org…" would lead "org…h-test".
        let m = "org.kiwidesk.m-test"
        let h = "org.kiwidesk.h-test"
        let gather = binding(
            "cmd+3",
            "KiwiDesk.gather(\"\(m)\")",
            .application
        )
        let open = binding(
            "cmd+1",
            "KiwiDesk.focus_or_spawn(\"\(m)\")",
            .application
        )
        let new = binding(
            "cmd+2",
            "KiwiDesk.spawn_new(\"\(m)\")",
            .application
        )
        let reference = build([
            gather, open, new,
            binding(
                "cmd+4",
                "KiwiDesk.focus_or_spawn(\"\(h)\")",
                .application
            ),
        ])
        #expect(reference.apps.map(\.appName) == [h, m, m, m])
        // Each title on its own row: a swap keeps the set of three.
        func title(_ key: KeyBinding) -> String? {
            reference.apps.first { $0.id == key.id.uuidString }?.label
        }
        #expect(title(gather) == "Gather \(m) Windows")
        #expect(title(new) == "New \(m) Window")
        #expect(title(open) == m)
        #expect(reference.apps.allSatisfy { $0.accessoryIcon == nil })
    }

    @Test("an app row's App Font glyph is its app's, not its title's")
    func appGlyphReadsTheAppName() throws {
        var gather = ShortcutRow(
            id: "g",
            label: "Gather Safari Windows",
            combo: ""
        )
        gather.appName = "Safari"
        let own = ShortcutRow(id: "o", label: "KiwiDesk", combo: "")
        let rows = JumpPanelController.glyphed([gather, own]) {
            ["Safari": "safari", "KiwiDesk": "kiwi"][$0]
        }
        #expect(rows.map(\.glyph) == ["safari", "kiwi"])
        // And the panel's App Font pass goes through it.
        let panel = try String(
            contentsOf: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(
                    "Sources/KiwiDesk/Jump/JumpPanelController+Shortcuts.swift"
                ),
            encoding: .utf8
        )
        #expect(
            SourceScan.stripComments(panel).contains(
                "out.apps = glyphed(reference.apps) {"
            )
        )
    }
}
