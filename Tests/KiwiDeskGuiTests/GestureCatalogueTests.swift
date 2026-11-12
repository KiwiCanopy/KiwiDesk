import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The one action catalogue (#3199 ▸ One catalogue, guards owed;
/// #3183): built from the Built-in page's parts, round-tripping a
/// pick through a gesture binding, and built by two views alone.
/// Main-actor spend: one catalogue build and one tree scan.
@Suite("Gesture action catalogue (#3183)")
@MainActor
struct GestureCatalogueTests {
    private var expander: ShortcutsFamilyRows {
        ShortcutsFamilyRows(
            spaces: [],
            icons: [:],
            desktops: .init(desktops: []),
            resizeStep: 40,
            layerNames: [KeyLayer.defaultName],
            currentLayer: KeyLayer.defaultName
        )
    }

    @Test("the catalogue's parts are the Built-in page's, inactive out")
    func partsAreThePage() {
        let page = ShortcutsPagePart.parts(in: .builtIn)
        #expect(SequenceActionCatalog.parts == page.filter { $0 != .inactive })
        let catalog = SequenceActionCatalog(expander: expander)
        let titles = Set(
            SequenceActionCatalog.parts.compactMap { $0.group?.control.text }
        )
        #expect(!catalog.groups.isEmpty)
        #expect(catalog.groups.allSatisfy { titles.contains($0.title) })
    }

    @Test("every command picked into a gesture reads back as itself")
    func pickRoundTrips() {
        let catalog = SequenceActionCatalog(expander: expander)
        let commands = catalog.groups.flatMap(\.commands)
        #expect(commands.count > 10)
        for command in commands {
            let action = GestureAction.run(
                LuaAction(lua: command.lua, kind: .navigation)
            )
            var base = GestureMap()
            let key = GestureKey(.tap5)
            GestureListEdits.set(action, at: key, in: &base)
            guard
                case .run(let stored) = GestureListEdits.action(
                    of: key,
                    in: base
                )
            else {
                Issue.record("\(command.lua) did not store as Lua")
                continue
            }
            #expect(catalog.command(running: stored.lua)?.lua == command.lua)
        }
    }

    @Test("only the key-sequence card and the gesture cards build one")
    func twoBuilders() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk")
        var builders: [String] = []
        for url in try SourceScan.swiftSources(under: root) {
            let text = try SourceScan.strippedSource(at: url)
            if text.contains("SequenceActionCatalog(expander:") {
                builders.append(url.lastPathComponent)
            }
        }
        #expect(
            builders.sorted()
                == ["GesturesPart.swift", "KeySequencesCard.swift"]
        )
    }
}
