import AppKit
import Testing

@testable import KiwiDeskCore

/// A bar manager hides its display's overlay and never drops it
/// (#1838): the section's root keeps its place on its shelf, so a
/// bar coming back is the same section re-shown rather than a new
/// one joining — which on a lone shelf took the fused join arm and
/// flew in. Only a display that left is retired.
@Suite("Bar managers keep their overlays", .serialized)
@MainActor
struct BarManagerKeepTests {
    @Test("The App Bar manager keeps its overlay across a hide")
    func appBarKeeps() throws {
        let apps = AppBarManager()
        let bar = AppBarManager.Bar(
            display: barTitleDisplay,
            space: SpaceID("1"),
            items: [AppBarOverlay.Item(id: WindowID(1), text: "A", icon: nil)],
            activeIndex: nil,
            strip: barTitleStrip,
            style: AppBarLook(),
            capAxis: barTitleStrip.width
        )
        apps.sync([bar])
        let shown = try #require(apps.shownOverlay(on: barTitleDisplay))
        apps.sync([])
        #expect(apps.shownOverlay(on: barTitleDisplay) == nil)
        #expect(apps.overlayForTesting(barTitleDisplay) === shown)
        apps.sync([bar])
        #expect(apps.shownOverlay(on: barTitleDisplay) === shown)
        apps.retire(except: [])
        #expect(apps.overlayForTesting(barTitleDisplay) == nil)
    }

    @Test("The Space Bar manager keeps its overlay across a hide")
    func spaceBarKeeps() throws {
        let spaces = SpaceBarManager()
        let bar = paintedSpaceBar(front: nil, spaces: 2)
        spaces.sync([bar])
        let shown = try #require(spaces.shownOverlay(on: barTitleDisplay))
        spaces.sync([])
        #expect(spaces.shownOverlay(on: barTitleDisplay) == nil)
        #expect(spaces.overlayForTesting(barTitleDisplay) === shown)
        spaces.sync([bar])
        #expect(spaces.shownOverlay(on: barTitleDisplay) === shown)
        spaces.retire(except: [])
        #expect(spaces.overlayForTesting(barTitleDisplay) == nil)
    }
}
