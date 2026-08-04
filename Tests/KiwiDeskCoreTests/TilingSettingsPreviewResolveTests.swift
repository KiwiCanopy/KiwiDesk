import Foundation
import Testing

@testable import KiwiDeskCore

/// `TilingSettings.resolved(for:activeMode:)` (#678 8b) — the seam
/// the per-space override editor's live preview feeds to the shared
/// schematic. It must overlay the ACTIVE layout's params with the
/// space's overrides and leave every other layout global, so the
/// preview shows exactly what that space's active layout would do.
struct TilingSettingsPreviewResolveTests {
    private func settingsWithBspOverride() -> TilingSettings {
        var s = TilingSettings()
        s.bsp.splitRatioH = 0.5
        var over = BspOverride()
        over.splitRatioH = 0.7
        s.bsp.override[SpaceID("a")] = over
        return s
    }

    @Test("the active layout is resolved with the space's override")
    func activeModeOverlaysOverride() {
        let s = settingsWithBspOverride()
        let resolved = s.resolved(for: SpaceID("a"), activeMode: .bsp)
        #expect(resolved.bsp.splitRatioH == 0.7)
    }

    /// A space whose ACTIVE layout is Stack must see the global BSP
    /// ratio in the preview settings — its BSP override belongs to a
    /// layout it is not currently using, so overlaying it would draw
    /// a Stack preview off the wrong numbers.
    @Test("a non-active layout keeps its global params")
    func inactiveModeStaysGlobal() {
        let s = settingsWithBspOverride()
        let resolved = s.resolved(
            for: SpaceID("a"),
            activeMode: .stack
        )
        #expect(resolved.bsp.splitRatioH == 0.5)
    }

    @Test("a space with no override resolves the global values")
    func noOverrideResolvesGlobal() {
        let s = settingsWithBspOverride()
        let resolved = s.resolved(for: SpaceID("b"), activeMode: .bsp)
        #expect(resolved.bsp.splitRatioH == 0.5)
    }

    @Test("Floating returns the settings untouched")
    func floatingIsUntouched() {
        let s = settingsWithBspOverride()
        let resolved = s.resolved(
            for: SpaceID("a"),
            activeMode: .floating
        )
        #expect(resolved.bsp.splitRatioH == 0.5)
    }
}
