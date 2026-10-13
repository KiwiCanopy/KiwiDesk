import AppKit
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The key panel's Shortcuts side (#2246): the query narrows the
/// sheet by name, every verb row wears a glyph, and the sheet lists
/// none of the panel's own openers.
@Suite("The key panel's Shortcuts side")
@MainActor
struct ShortcutsSheetTests {
    private static func row(_ label: String) -> ShortcutRow {
        ShortcutRow(id: label, label: label, combo: "⌃⌥X")
    }

    private static let reference = ShortcutsReference(
        layerName: KeyLayer.defaultName,
        controls: [
            ShortcutSubgroup(
                title: "Focus",
                rows: [row("Go to Space 2"), row("Focus window above")]
            ),
            ShortcutSubgroup(
                title: "Move windows",
                rows: [row("Move to Space 2")]
            ),
        ],
        inactive: [row("Go to Space 9")],
        apps: [row("Open Settings"), row("Safari")],
        custom: [row("KiwiDesk.notify()")]
    )

    @Test("the query keeps matching rows and their sections' titles")
    func queryNarrows() {
        var sheet = ShortcutsSheet(reference: Self.reference)
        sheet.setQuery("  space 2 ")
        let shown = sheet.shown
        #expect(shown?.controls.map(\.title) == ["Focus", "Move windows"])
        #expect(shown?.controls.first?.rows.map(\.label) == ["Go to Space 2"])
        #expect(shown?.apps.isEmpty == true)
        #expect(shown?.inactive.isEmpty == true)
        #expect(sheet.matchCount == 2)
    }

    @Test("an empty query shows the whole sheet")
    func emptyShowsAll() {
        let sheet = ShortcutsSheet(reference: Self.reference)
        #expect(sheet.matchCount == 7)
    }

    @Test("a match ignores case and diacritics")
    func matchIsLoose() {
        #expect(ShortcutsSheet.matchRange(of: "SAFA", in: "Safari") != nil)
        #expect(ShortcutsSheet.matchRange(of: "x", in: "Space") == nil)
        #expect(ShortcutsSheet.matchRange(of: "e", in: "Café") != nil)
        #expect(ShortcutsSheet.matchRange(of: "", in: "Safari") == nil)
    }

    @Test("the column reads Controls, Apps, Custom, then Inactive")
    func sectionOrder() {
        LocalizationManager.shared.select("en")
        let view = ShortcutsSheetView(reference: Self.reference, needle: "")
        let titles = view.sections(Self.reference).map(\.title)
        #expect(
            titles == [
                "Focus", "Move windows", "Apps", "Custom",
                "Inactive shortcuts",
            ]
        )
        #expect(view.sections(Self.reference).last?.inactive == true)
    }

    @Test("every verb row wears a glyph that resolves")
    func verbGlyphsResolve() {
        let verbs = [
            "KiwiDesk.cycle_mode()", "KiwiDesk.cycle_mode(\"prev\")",
            "KiwiDesk.resize(\"x\", 50)", "KiwiDesk.resize(\"x\", -50)",
            "KiwiDesk.resize(\"y\", 50)", "KiwiDesk.resize(\"y\", -50)",
            "KiwiDesk.toggle_floating()", "KiwiDesk.toggle_sticky()",
            "KiwiDesk.toggle_display_sticky()",
            "KiwiDesk.switch_layer(\"vim\")",
        ]
        let glyphs = verbs.map {
            ShortcutsReferenceBuilder.verbIcon(for: $0)
        }
        #expect(!glyphs.contains(nil))
        // Grow and shrink, width and height: four shapes.
        #expect(Set(glyphs[2...5].compactMap { $0 }).count == 4)
        for symbol in Set(
            glyphs.compactMap { $0 } + ShortcutsReferenceBuilder.verbSymbols
        ) {
            #expect(
                NSImage(
                    systemSymbolName: symbol,
                    accessibilityDescription: nil
                ) != nil,
                "\(symbol) does not resolve"
            )
        }
    }

    @Test("the sheet lists none of the panel's own openers")
    func openersDropped() {
        var layer = KeyLayer(name: KeyLayer.defaultName, bindings: [])
        for (index, scope) in JumpScope.allCases.enumerated() {
            layer.bindings.append(
                KeyBinding(
                    combo: "control+option+\(index)",
                    lua: scope.lua,
                    kind: .navigation
                )
            )
        }
        let reference = ShortcutsReferenceBuilder.build(
            layer: layer,
            spaces: [],
            spaceIcons: [:],
            desktops: [],
            resizeStep: 50,
            layerNames: [KeyLayer.defaultName]
        )
        #expect(reference.isEmpty)
    }

    @Test("Open Settings leads Apps on KiwiDesk's own icon")
    func openSettingsLeadsApps() {
        let layer = KeyLayer(
            name: KeyLayer.defaultName,
            bindings: [
                KeyBinding(
                    combo: "control+option+comma",
                    lua: KeybindingCatalog.openSettings.lua,
                    kind: .navigation
                )
            ]
        )
        let reference = ShortcutsReferenceBuilder.build(
            layer: layer,
            spaces: [],
            spaceIcons: [:],
            desktops: [],
            resizeStep: 50,
            layerNames: [KeyLayer.defaultName]
        )
        #expect(reference.controls.isEmpty)
        #expect(reference.apps.first?.ownApp == true)
        #expect(reference.custom.isEmpty)
    }
}
