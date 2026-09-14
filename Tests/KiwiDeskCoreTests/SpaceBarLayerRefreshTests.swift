import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// The Space Bar follows the active layer off the `layer_change`
/// bus event (#1169): a switch retiles nothing, so without the
/// sink the bar would show the layer only at the next retile.
/// Drives the real switch and reads the painted bar — nothing
/// here calls `updateSpaceBar` after the fixture is up.
@Suite("Space Bar layer refresh (#1169)", .serialized)
@MainActor
struct SpaceBarLayerRefreshTests {
    /// A core showing a Space Bar over one Space on the host's
    /// main screen; nil where the host has none to paint on.
    private func makeBarredCore(
        resolvingSpaces: Bool = true
    ) -> KiwiCore? {
        guard let screen = NSScreen.main,
            let display = screen.kiwiDisplay
        else { return nil }
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "kiwidesk-layer-refresh-\(UUID().uuidString)"
                )
        )
        // Pin the display rather than inherit it (#531).
        core.tiler.visibleBounds = { _ in screen.frame }
        core.state.apply(.displaysChanged([display]))
        if resolvingSpaces {
            core.resolveSpaceDisplays(mainID: display.id)
        }
        core.tiler.settings.spaceBarStyle.enabled = true
        core.tiler.settings.spaceBarStyle.edge = .top
        core.tiler.settings.spaceBarStyle.thickness = 40
        NativeSpaces.currentSpaceIsUserOverride = { _ in true }
        LiquidGlassGate.override = { false }
        core.updateSpaceBar()
        return core
    }

    private func identities(_ core: KiwiCore) -> [SpaceBarItemView.Identity] {
        guard let display = NSScreen.main?.kiwiDisplay?.id,
            let shown = core.spaceBars.overlayForTesting(display)?
                .lastShown
        else { return [] }
        return shown.items.map(\.identity)
    }

    @Test(
        "a layer switch re-draws the bar with the layer in front",
        .enabled(if: NSScreen.main != nil)
    )
    func switchLeadsTheRun() throws {
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let core = try #require(makeBarredCore())
        let before = identities(core)
        try #require(!before.isEmpty, "no bar painted")
        #expect(before.allSatisfy { $0 != .layer("resize") })
        core.keys.defineLayer("resize", bindings: [:])
        core.keys.switchLayer("resize")
        let during = identities(core)
        #expect(during.first == .layer("resize"))
        #expect(Array(during.dropFirst()) == before)
        core.keys.switchLayer("default")
        #expect(identities(core) == before)
    }

    /// The layer never draws a bar of its own: a screen with no
    /// Space item stays bare under an active layer.
    @Test(
        "a screen with no Spaces draws no bar for the layer",
        .enabled(if: NSScreen.main != nil)
    )
    func noSpacesNoBar() throws {
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let core = try #require(makeBarredCore(resolvingSpaces: false))
        try #require(core.spaceBars.shownDisplays.isEmpty)
        core.keys.defineLayer("resize", bindings: [:])
        core.keys.switchLayer("resize")
        #expect(core.spaceBarLayerItem() != nil)
        #expect(core.spaceBars.shownDisplays.isEmpty)
    }
}
