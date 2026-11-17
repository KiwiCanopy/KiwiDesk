import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// `kiwishelf.set_pocket_edge` with the optional screen (#3376),
/// through `execute`: the bars' `ScreenEdged` doors (#1948) on the
/// pocket's edge — stored by fingerprint, collapsed over the live
/// scope, cleared by a screen-less call, kept by a look, resolved
/// per screen and encoded sparse.
@Suite("Per-screen pocket edge (#3376)", .serialized)
@MainActor
struct PocketScreenEdgeTests {
    private static let left = Display(
        id: DisplayID(7_101),
        name: "Left",
        frame: CGRect(x: 0, y: 0, width: 1920, height: 1080)
    )
    private static let right = Display(
        id: DisplayID(7_102),
        name: "Right",
        frame: CGRect(x: 1920, y: 0, width: 2560, height: 1440)
    )
    private static let away = "Away:800x600"
    private static let verb = "kiwishelf.set_pocket_edge"

    /// A core with both screens connected, `right` the main one;
    /// a test restores the main id it found.
    private func makeCore() -> KiwiCore {
        let core = makeTestCore()
        PositionalDisplays.mainIDOverride = { Self.right.id }
        core.state.apply(.displaysChanged([Self.left, Self.right]))
        core.execute(Self.verb, args: [.string("bottom")])
        return core
    }

    @discardableResult
    private func set(
        _ core: KiwiCore,
        _ args: JSONValue...
    ) -> CommandResponse {
        core.execute(Self.verb, args: args)
    }

    private var shelf: (KiwiCore) -> KiwiShelf {
        { $0.tiler.settings.kiwishelf }
    }

    @Test("a screen is named as a bar's is, and stored by fingerprint")
    func screenArgument() {
        let saved = PositionalDisplays.mainIDOverride
        defer { PositionalDisplays.mainIDOverride = saved }
        let core = makeCore()
        #expect(set(core, .string("left"), .string("Left")).isSuccess)
        #expect(set(core, .string("top"), .string(Self.away)).isSuccess)
        #expect(
            shelf(core).pocketEdgeOverride == [
                Self.left.fingerprint: .left, Self.away: .top,
            ]
        )
        #expect(shelf(core).pocketEdge == .bottom)
        let refused = set(core, .string("left"), .string("Nope"))
        #expect(refused.error == KiwiCore.unknownScreen)
        let badEdge = set(core, .string("diagonal"), .string("Nope"))
        #expect(badEdge.error?.hasPrefix("expected top") == true)
    }

    @Test("the pocket's own edge stores nothing; one edge collapses")
    func collapse() {
        let saved = PositionalDisplays.mainIDOverride
        defer { PositionalDisplays.mainIDOverride = saved }
        let core = makeCore()
        #expect(set(core, .string("bottom"), .string("Left")).isSuccess)
        #expect(shelf(core).pocketEdgeOverride.isEmpty)
        // Both connected screens on one edge: it becomes the pocket's.
        set(core, .string("left"), .string("Left"))
        set(core, .string("left"), .string("Right"))
        #expect(shelf(core).pocketEdgeOverride.isEmpty)
        #expect(shelf(core).pocketEdge == .left)
        // A screen-less call clears every screen's own edge.
        set(core, .string("top"), .string("Left"))
        #expect(!shelf(core).pocketEdgeOverride.isEmpty)
        #expect(set(core, .string("right")).isSuccess)
        #expect(shelf(core).pocketEdgeOverride.isEmpty)
        #expect(shelf(core).pocketEdge == .right)
    }

    @Test("each screen's pocket reads its own edge")
    func resolvesPerScreen() {
        let saved = PositionalDisplays.mainIDOverride
        defer { PositionalDisplays.mainIDOverride = saved }
        let core = makeCore()
        set(core, .string("left"), .string("Left"))
        #expect(core.shelf(on: Self.left.id).pocketEdge == .left)
        #expect(core.shelf(on: Self.right.id).pocketEdge == .bottom)
        #expect(
            core.settings(on: Self.left.id).kiwishelf.pocketEdge == .left
        )
        let resolved = core.tiler.settings.onScreen(Self.left.fingerprint)
        #expect(resolved.kiwishelf.pocketEdgeOverride.isEmpty)
        #expect(
            core.tiler.settings.screenVariants.map(\.kiwishelf.pocketEdge)
                .contains(.left)
        )
    }

    @Test("a look sets the pocket's edge and keeps each screen's own")
    func lookKeepsScreens() {
        var settings = TilingSettings()
        settings.kiwishelf.pocketEdgeOverride = [
            Self.left.fingerprint: .left, Self.right.fingerprint: .top,
        ]
        ShelfLook.apply(
            path: "kiwishelf.pocket_edge",
            value: .string("top"),
            to: &settings
        )
        #expect(settings.kiwishelf.pocketEdge == .top)
        // Untouched, the entry the look's edge now equals too.
        #expect(
            settings.kiwishelf.pocketEdgeOverride == [
                Self.left.fingerprint: .left, Self.right.fingerprint: .top,
            ]
        )
    }

    @Test("a forgotten screen setup drops its pocket entries")
    func keepScreensDrops() {
        var settings = TilingSettings()
        settings.kiwishelf.pocketEdgeOverride = [
            "Kept:100x100": .left, "Gone:100x100": .top,
        ]
        settings.keepScreenEdges(
            in: ScreenEdgeScope(screens: ["Kept:100x100"])
        )
        #expect(
            settings.kiwishelf.pocketEdgeOverride == ["Kept:100x100": .left]
        )
    }

    @Test("the map encodes sparse and round-trips")
    func encodesSparse() throws {
        var shelf = KiwiShelf()
        let empty = try JSONEncoder().encode(shelf)
        #expect(
            !String(decoding: empty, as: UTF8.self)
                .contains("pocket_edge_override")
        )
        shelf.pocketEdgeOverride = ["LG:3840x2160": .right]
        let data = try JSONEncoder().encode(shelf)
        let back = try JSONDecoder().decode(KiwiShelf.self, from: data)
        #expect(back.pocketEdgeOverride == ["LG:3840x2160": .right])
    }
}
