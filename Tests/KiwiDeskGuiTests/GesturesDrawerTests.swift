import CoreGraphics
import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// Shortcuts & Gestures ▸ Mouse & trackpad (#1726): where the
/// drawer mounts, what left Behavior for it, how its entries grey,
/// and the Behavior card's replacement picture.
@Suite("Mouse & trackpad drawer")
struct GesturesDrawerTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    private static func source(_ path: String) throws -> String {
        SourceScan.stripComments(
            try String(
                contentsOf: root.appendingPathComponent(path),
                encoding: .utf8
            )
        )
    }

    private static let settings = "Sources/KiwiDesk/Settings/"

    @Test("both bar-off notes place their link")
    @MainActor
    func offNotesPlaceTheirLink() {
        let slot = CrossReferenceRow.linkSlot
        #expect(GesturesShelfEntries.spaceBarOffProse.contains(slot))
        #expect(GesturesShelfEntries.appBarOffProse.contains(slot))
    }

    /// Above the layer header, so nothing in it reads as
    /// per-layer: located by the header's own mount, which the
    /// drawer's position is relative to.
    @Test("the drawer mounts above the layer header")
    func mountsAboveTheLayerHeader() throws {
        let body = try Self.source(
            Self.settings + "Sections/ShortcutsSection.swift"
        )
        let drawer = try #require(
            body.range(of: "GesturesDrawer(model: model)")
        )
        let header = try #require(body.range(of: "ShortcutsHeader("))
        #expect(drawer.lowerBound < header.lowerBound)
        #expect(
            body.components(separatedBy: "GesturesDrawer(").count
                == 2,
            "the drawer mounts exactly once"
        )
    }

    /// The mouse rows left Behavior: no Behavior file still draws
    /// either control, so the move cannot leave a second copy.
    @Test("Behavior no longer draws the mouse rows")
    func behaviorDropsTheMouseRows() throws {
        let body = try Self.source(
            Self.settings + "Sections/BehaviorSection.swift"
        )
        #expect(!body.isEmpty)
        #expect(!body.contains("mouseResize"))
        #expect(!body.contains("followsFocus"))
        let drawer = try Self.source(
            Self.settings + "Components/Gestures/GesturesDrawer.swift"
        )
        #expect(drawer.contains("MouseResizePicker("))
        #expect(drawer.contains(".mouse.followsFocus"))
    }

    /// Each entry greys on the bar it teaches: the Space entries
    /// on the Space Bar, the reorder on any App Bar, the scroll on
    /// the shelf — each keyed on its own use site.
    @Test("shelf entries grey on their own bar")
    func shelfEntriesGreyOnTheirBar() throws {
        let body = try Self.source(
            Self.settings
                + "Components/Gestures/GesturesShelfEntries.swift"
        )
        let squashed = body.split(whereSeparator: \.isWhitespace)
            .joined()
        #expect(squashed.contains("GreyOut(active:!spaceBarOn)"))
        #expect(
            squashed.contains(
                "GreyOut(active:!settings.anyAppBarCanShow)"
            )
        )
        #expect(
            squashed.contains("GreyOut(active:!settings.shelfShows)")
        )
        #expect(
            squashed.contains(
                "shown:!settings.anyAppBarCanShow,prose:Self.appBarOffProse"
            )
        )
        #expect(
            squashed.contains(
                "offNote(shown:!spaceBarOn,prose:Self.spaceBarOffProse)"
            )
        )
    }

    /// The Behavior card's picture is the engine's quit grid for
    /// the draft's target depth, so it answers when the depth
    /// moves — a constant drawing would not.
    /// `@MainActor` because the tile is a `View`; the spend is
    /// two small layouts.
    @Test("the Behavior tile draws the engine's quit grid")
    @MainActor
    func behaviorTileFollowsTheDepth() {
        var shallow = TilingSettings()
        shallow.quitGridTargetDepth = 1
        var deep = TilingSettings()
        deep.quitGridTargetDepth = 20
        let size = CGSize(width: 160, height: 100)
        let a = HomeCardBehaviorTile.frames(in: size, settings: shallow)
        let b = HomeCardBehaviorTile.frames(in: size, settings: deep)
        #expect(a.count == HomeCardBehaviorTile.sampleCount)
        #expect(b.count == HomeCardBehaviorTile.sampleCount)
        #expect(a != b, "the target depth changed nothing")
        let ids = (1...HomeCardBehaviorTile.sampleCount)
            .map { WindowID(UInt32($0)) }
        let engine = QuitGridLayout.frames(
            for: ids,
            in: CGRect(origin: .zero, size: size),
            minSize: 6,
            targetDepth: 1
        )
        #expect(a == ids.compactMap { engine[$0] })
    }
}
