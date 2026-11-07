import Foundation
import Testing

@testable import KiwiDeskCore

/// Every bar's visibility is one set (#761): what
/// `setEveryBarVisibility` writes, `uniformBarVisibility` reads and
/// `takeBarVisibility` copies back must be the same leaves, or a
/// tour Revert leaves one behind (#2515).
@Suite("Every bar's visibility is one set")
struct BarVisibilitySetTests {
    /// Settings whose bars all differ, so a leaf the copier misses
    /// is still set by the writer and the round trip reds.
    private func apart() -> TilingSettings {
        var settings = TilingSettings()
        settings.spaceBarStyle.visibility = .hidden
        for mode in LayoutMode.allCases {
            settings.setAppBarVisibility(.auto, in: mode)
        }
        return settings
    }

    @Test("a copy back undoes the writer on every leaf")
    func copyUndoesTheWriter() {
        let original = apart()
        for visibility in ShelfVisibility.allCases {
            var written = original
            written.setEveryBarVisibility(visibility)
            expectEqual(written.uniformBarVisibility, visibility)
            written.takeBarVisibility(from: original)
            #expect(written == original, "\(visibility)")
        }
    }

    @Test("the copy takes the visibility and nothing else")
    func copyTakesOnlyVisibility() {
        var source = apart()
        source.resizeStep += 7
        var target = TilingSettings()
        target.takeBarVisibility(from: source)
        expectEqual(target.resizeStep, TilingSettings().resizeStep)
        expectEqual(target.spaceBarStyle.visibility, .hidden)
    }
}
