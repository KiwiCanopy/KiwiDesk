import CoreGraphics
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The screen line under a Desktops-card row (#1438): a live row
/// is named by the topology, a dormant one by what its record
/// remembers, and the model hands the view the topology's half
/// from the same snapshot as the keys.
///
/// `.serialized`: the topology overrides are process-global.
@MainActor
@Suite("Desktop row screen line (#1438)", .serialized)
struct DesktopRowScreenTests {
    private let live = DesktopKey.identity(DesktopIdentity(raw: "LIVE"))
    private let gone = DesktopKey.identity(DesktopIdentity(raw: "GONE"))

    private func rows(
        screens: [DesktopKey: String],
        bindings: [DesktopKey: DesktopBinding]
    ) -> [DesktopRow] {
        ProfilesFamilyRows.desktops(
            onMain: [1],
            keys: [1: live],
            present: [live, .number(1)],
            screens: screens,
            bindings: bindings
        )
    }

    /// The topology names a live row — over the record, which
    /// can be stale by one reading.
    @Test("a live row takes the topology's screen")
    func liveRowTakesTheTopologyScreen() {
        let listed = rows(
            screens: [live: "Built-in"],
            bindings: [
                live: DesktopBinding(
                    profile: "Work",
                    desktop: 1,
                    screen: "Old"
                )
            ]
        )
        #expect(listed.first { $0.key == live }?.screen == "Built-in")
    }

    /// No reading names a dormant Desktop, so its row says
    /// where it was last seen — the one thing that tells it
    /// from the live row sharing its number.
    @Test("a dormant row takes the remembered screen")
    func dormantRowTakesTheRememberedScreen() {
        let listed = rows(
            screens: [live: "Built-in"],
            bindings: [
                gone: DesktopBinding(
                    profile: "Work",
                    desktop: 1,
                    screen: "LG UltraFine"
                )
            ]
        )
        #expect(listed.map(\.number) == [1, 1])
        #expect(
            listed.first { $0.key == gone }?.screen == "LG UltraFine"
        )
    }

    /// A live row the topology cannot name falls back to its
    /// record, and a row nothing has named draws no line.
    @Test("an unnamed row falls back to its record, then to nothing")
    func unnamedRowFallsBack() {
        let remembered = rows(
            screens: [:],
            bindings: [
                live: DesktopBinding(
                    profile: "Work",
                    desktop: 1,
                    screen: "Built-in"
                )
            ]
        )
        #expect(
            remembered.first { $0.key == live }?.screen == "Built-in"
        )
        let bare = rows(screens: [:], bindings: [:])
        #expect(bare.first { $0.key == live }?.screen == nil)
    }

    /// The model's half: `refreshProfiles` fills `desktopScreens`
    /// from Core over the snapshot the keys came from, so the
    /// view is handed a name for every present Desktop.
    @Test("the refresh names each present Desktop's screen")
    func refreshNamesTheScreens() {
        defer {
            NativeSpaces.spacesOverride = nil
            NativeSpaces.mainDisplayUUIDOverride = nil
            NativeSpaces.activeSpaceIDOverride = nil
            NativeSpaces.displayUUIDOverride = nil
        }
        let stamp = DesktopIdentity(raw: "STAMP-A")
        NativeSpaces.spacesOverride = [
            NativeSpace(
                id: 10,
                displayUUID: "UUID-A",
                isCurrent: true,
                identity: stamp
            )
        ]
        NativeSpaces.mainDisplayUUIDOverride = "UUID-A"
        NativeSpaces.activeSpaceIDOverride = 10
        NativeSpaces.displayUUIDOverride = { _ in "UUID-A" }
        let model = makeTestModel(
            core: makeTestCore(
                configDirectory: FileManager.default
                    .temporaryDirectory
                    .appendingPathComponent(
                        "kiwi-row-screen-\(UUID().uuidString)"
                    )
            )
        )
        model.core.state.workspaces.upsertDisplay(
            Display(
                id: DisplayID(1),
                name: "Built-in",
                frame: CGRect(x: 0, y: 0, width: 100, height: 100)
            )
        )
        model.refreshProfiles()
        #expect(model.desktopScreens[.identity(stamp)] == "Built-in")
        #expect(model.desktopKeys[1] == .identity(stamp))
    }

    /// The view's half, which no model test can see: the card
    /// hands the model's names to the row builder, and a pick
    /// files the row's screen on the record it writes.
    @Test("the card threads the screens and files them on a pick")
    func cardThreadsTheScreens() throws {
        func squashed(_ name: String) throws -> String {
            let path = SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(
                    "Sources/KiwiDesk/Settings/Components/Profiles/"
                        + name
                )
            return SourceScan.stripComments(
                try String(contentsOf: path, encoding: .utf8)
            )
            .split(whereSeparator: \.isWhitespace)
            .joined()
        }
        let card = try squashed("DesktopsGroup.swift")
        #expect(card.contains("screens:model.desktopScreens,"))
        let row = try squashed("DesktopsGroup+Row.swift")
        #expect(row.contains("record.screen=row.screen??record.screen"))
        #expect(row.contains("set:{write($0,key:key,slot:slot)}"))
        #expect(row.contains("ifletscreen=row.screen{Text(screen)"))
    }
}
