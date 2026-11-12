import Testing

@testable import KiwiDesk

/// The KiwiVision page's row gates against the census (#2103):
/// split from `KiwiVisionCensusRenderTests` at the file ceiling.
@Suite("KiwiVision gates ↔ census")
struct KiwiVisionGateCensusTests {
    /// Every row is app-wide, so it greys only where `init.lua`
    /// owns the config, as the resolver answers.
    @Test("every row's gate is the Lua-owned one, resolved here")
    @MainActor func rowGates() {
        // Every key draws a row since the lens page (#2103 PR 7),
        // save the fade length, Lua-only since #3238.
        let drawn = KiwiVisionKey.allCases.filter {
            SettingKey.kiwiVision($0).placement.area == .kiwiVision
        }
        #expect(drawn.count == KiwiVisionKey.allCases.count - 1)
        #expect(
            SettingKey.kiwiVision(.fadeDuration).placement == .luaOnly
        )
        for key in drawn {
            #expect(
                SettingKey.kiwiVision(key).placement.gate
                    == .runtime(.luaOwnsConfig)
            )
        }
        #expect(
            KiwiVisionGates.resolved
                == Set(drawn.map(SettingKey.kiwiVision))
        )
        let owned = KiwiVisionGates(guiManaged: false)
        let managed = KiwiVisionGates(guiManaged: true)
        for key in KiwiVisionGates.resolved {
            #expect(owned.inertReason(for: key) == .appWideLuaOwned)
            #expect(managed.inertReason(for: key) == nil)
        }
    }
}
