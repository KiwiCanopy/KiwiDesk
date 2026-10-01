import AppKit
import Testing

@testable import KiwiDeskCore

/// A Space with no front app draws no front chip: under box glass
/// the chip is a glass AND the tint painted beneath it, and a tint
/// left showing reads as a dark chip where the last app was.
@Suite("Front-app glass hides with its tint")
@MainActor
struct SpaceBarFrontGlassHideTests {
    /// Reduce transparency is pinned off (#660, #1374).
    init() { LiquidGlassGate.override = { false } }

    private func bar(front: WindowID?) -> SpaceBarManager.Bar {
        let base = paintedSpaceBar(front: front, spaces: 3)
        var style = base.style
        style.shelf.backgroundStyle = .boxed
        style.shelf.liquidGlass = true
        return SpaceBarManager.Bar(
            display: base.display,
            items: base.items,
            frontApp: base.frontApp,
            frontWindow: base.frontWindow,
            strip: base.strip,
            style: style,
            stateMarkColors: base.stateMarkColors
        )
    }

    @Test("leaving the front app hides the chip's glass and tint")
    func emptySpaceHidesTint() throws {
        guard #available(macOS 26, *) else { return }
        let manager = SpaceBarManager()
        manager.sync([bar(front: WindowID(1))])
        let overlay = try #require(
            manager.overlayForTesting(barTitleDisplay)
        )
        let tint = try #require(overlay.frontTint)
        try #require(!tint.isHidden)
        manager.sync([bar(front: nil)])
        #expect(overlay.frontGlass?.isHidden ?? true)
        #expect(tint.isHidden, "the front chip's tint still shows")
    }
}
