import AppKit
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// Every row on KiwiHub's Shortcuts side wears a symbol (#2530):
/// rows have shipped bare more than once, since a verb no case of
/// the icon chain matched silently drew none. The commands are the
/// ones the builder's own band code hands its row maker, and each
/// is resolved through the builder's own `icon(for:)`, never a copy;
/// the seeded case reads `row.icon` off `build` itself, the check
/// that the builder calls that chain. A row `build` makes directly
/// (Apps' own Open Settings, drawn with the app icon) is outside the
/// recorded net. Main-actor spend: three builder passes, two seeded
/// keymaps and one symbol lookup per distinct symbol.
@Suite("Shortcut rows wear a symbol")
@MainActor
struct ShortcutRowSymbolTests {
    /// Rows meant to stay bare, each with its reason. Empty: a bare
    /// row is a defect until someone argues otherwise here.
    static let exempt: [String: String] = [:]

    /// Every command `buildControls` and `buildInactive` can draw,
    /// with Spaces, Desktops, layers and lenses present and absent.
    static func drawable() -> [NavCommand] {
        var seen: [NavCommand] = []
        let record: ([NavCommand]) -> [ShortcutRow] = { commands in
            seen += commands
            return []
        }
        _ = ShortcutsReferenceBuilder.buildControls(
            activeLayer: KeyLayer.defaultName,
            spaces: ["1", "2", "web"],
            spaceIcons: ["web": "globe"],
            desktops: .init(desktops: [1, 2, 3], absent: [3]),
            resizeStep: 50,
            layerNames: [KeyLayer.defaultName, "Mouse"],
            lenses: ["Reading"],
            rows: { commands, _ in record(commands) }
        )
        let orphans = KeyLayer(
            name: KeyLayer.defaultName,
            bindings: [
                "KiwiDesk.focus_space(\"9\")",
                "KiwiDesk.move_to_space(\"gone\")",
                "KiwiDesk.switch_layer(\"Gone\")",
            ].map {
                KeyBinding(
                    combo: "control+option+0",
                    lua: $0,
                    kind: .navigation
                )
            }
        )
        _ = ShortcutsReferenceBuilder.buildInactive(
            orphans,
            spaces: ["1"],
            layers: [KeyLayer.defaultName],
            spaceIcons: [:],
            rows: record
        )
        return seen
    }

    @Test("every drawable command resolves to a symbol")
    func everyCommandHasASymbol() {
        let commands = Self.drawable()
        #expect(commands.count > 30, "recorded too few commands")
        for command in commands where Self.exempt[command.lua] == nil {
            #expect(
                ShortcutsReferenceBuilder.icon(for: command) != nil,
                "\(command.lua) draws no symbol"
            )
        }
    }

    /// KiwiHub's sides draw as the panel's segments, never as rows
    /// there, so `drawable()` misses them; their Settings rows
    /// still wear a glyph (#2670).
    @Test("KiwiHub's side rows wear a symbol that resolves")
    func kiwiHubSidesHaveSymbols() {
        let rows = KeybindingCatalog.kiwiHubRows
        #expect(rows.count == 3)
        for command in rows {
            guard let name = ShortcutsReferenceBuilder.icon(for: command)
            else {
                Issue.record("\(command.lua) draws no symbol")
                continue
            }
            let image = NSImage(
                systemSymbolName: name,
                accessibilityDescription: nil
            )
            #expect(image != nil, "\(name) does not resolve")
        }
    }

    @Test("every exemption names a command the panel draws")
    func exemptionsAreLive() {
        let drawn = Set(Self.drawable().map(\.lua))
        for lua in Self.exempt.keys {
            #expect(drawn.contains(lua), "stale exemption \(lua)")
        }
    }

    @Test("every symbol a row draws resolves on this macOS")
    func everySymbolResolves() {
        let symbols = Set(
            Self.drawable().compactMap(ShortcutsReferenceBuilder.icon(for:))
        )
        for symbol in symbols {
            let image = NSImage(
                systemSymbolName: symbol,
                accessibilityDescription: nil
            )
            #expect(
                image != nil,
                "\(symbol) does not resolve"
            )
        }
    }

    /// A one-sided line arrow means a focus move and nothing else
    /// (#2529 ▸ Ruling), whichever chain arm would draw it.
    @Test("only a focus row wears a one-sided line arrow")
    func lineArrowsAreFocusOnly() {
        let lines = Set(
            KeybindingCatalog.directionNames.map { "arrow.\($0)" }
        )
        let focus = Set(KeybindingCatalog.focusDirections.map(\.lua))
        let wearing = Self.drawable().filter {
            ShortcutsReferenceBuilder.icon(for: $0).map(lines.contains)
                ?? false
        }
        #expect(Set(wearing.map(\.lua)) == focus)
        let folds = ShortcutFold.Family.allCases.compactMap(
            ShortcutsReferenceBuilder.foldIcon(for:)
        )
        #expect(!folds.isEmpty)
        #expect(Set(folds).isDisjoint(with: lines), "a fold wears one way")
    }

    /// The seeded keymap, on both bases: every row is recognised
    /// (none falls to Custom as raw Lua) and wears a symbol.
    @Test("every seeded row is recognised and wears a symbol")
    func seededRowsHaveSymbols() {
        for base in ShortcutBase.allCases {
            let layer = KeyLayer(
                name: KeyLayer.defaultName,
                bindings: DefaultKeybindings.bindings(
                    spaces: ["1", "2", "3"],
                    resizeStep: 50,
                    base: base
                )
            )
            let reference = ShortcutsReferenceBuilder.build(
                layer: layer,
                spaces: ["1", "2", "3"],
                spaceIcons: [:],
                desktops: [1, 2],
                resizeStep: 50,
                layerNames: [KeyLayer.defaultName]
            )
            #expect(
                reference.custom.isEmpty,
                "\(base): unrecognised \(reference.custom.map(\.id))"
            )
            let rows = reference.controls.flatMap(\.rows)
            #expect(rows.count > 10, "\(base): only \(rows.count) rows")
            for row in rows where Self.exempt[row.id] == nil {
                #expect(row.icon != nil, "\(base): \(row.id) is bare")
            }
        }
    }
}
