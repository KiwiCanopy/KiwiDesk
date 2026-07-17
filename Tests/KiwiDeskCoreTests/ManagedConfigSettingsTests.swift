import Testing

@testable import KiwiDeskCore

/// `ManagedConfig.declaresManagedSettings` (#354): the seed-gating
/// predicate. A superset of `hasForeignCode` — it also flags the
/// `KiwiDesk.set_*` verbs that editor-fallback deliberately
/// ignores, so a Lua config that configures tiling is never seeded
/// over, while a hooks-only file still earns the GUI defaults.
@Suite("ManagedConfig declares-settings (#354)")
struct ManagedConfigSettingsTests {
    @Test("a set_* verb declares settings (hasForeignCode misses it)")
    func setVerbDeclaresSettings() {
        let source = """
            KiwiDesk.set_gap_global(30)
            KiwiDesk.set_mode(1, "stack")
            """
        // The exact gap: not foreign, but it IS a settings config.
        #expect(!ManagedConfig.hasForeignCode(source))
        #expect(ManagedConfig.declaresManagedSettings(source))
    }

    @Test("namespaced layout setters declare settings")
    func namespacedSetterDeclaresSettings() {
        // The bulk of the settings surface lives on namespace
        // tables, not KiwiDesk — a substring check for
        // `KiwiDesk.set_` misses these and would seed over them.
        #expect(
            ManagedConfig.declaresManagedSettings(
                "bsp.set_ratio_h(0.6)"
            )
        )
        #expect(
            ManagedConfig.declaresManagedSettings(
                "stack.set_master_ratio(0.7)"
            )
        )
        #expect(
            ManagedConfig.declaresManagedSettings(
                "scroll.set_slot_size(600)"
            )
        )
    }

    @Test("border.fit_gaps declares settings (non-set_ verb)")
    func fitGapsDeclaresSettings() {
        // The one config-writing verb without a set_ name — it
        // rewrites the global gap, so it must gate the seed.
        #expect(
            ManagedConfig.declaresManagedSettings(
                "border.fit_gaps(5)"
            )
        )
    }

    @Test("an unrelated foo.set_ call is not a settings signal")
    func unknownNamespaceIsNotSettings() {
        // Anchored to known namespace tables, so a user's own
        // `foo.set_bar()` doesn't read as KiwiDesk config.
        #expect(
            !ManagedConfig.declaresManagedSettings(
                "foo.set_bar(1)"
            )
        )
    }

    @Test("hooks-only config declares no settings")
    func hooksOnlyDeclaresNothing() {
        let source = """
            for _, event in ipairs({ "space_change" }) do
                KiwiDesk.on(event, function()
                    KiwiDesk.exec("sketchybar --trigger x")
                end)
            end
            """
        #expect(!ManagedConfig.declaresManagedSettings(source))
    }

    @Test("comment-only and empty declare no settings")
    func inertDeclaresNothing() {
        #expect(
            !ManagedConfig.declaresManagedSettings("-- notes\n")
        )
        #expect(!ManagedConfig.declaresManagedSettings(""))
    }

    @Test("rule tables and binds declare settings")
    func managedTokensDeclareSettings() {
        #expect(
            ManagedConfig.declaresManagedSettings(
                "float_rules = { \"com.apple.calculator\" }"
            )
        )
        #expect(
            ManagedConfig.declaresManagedSettings(
                "KiwiDesk.bind(\"alt+h\", function() end)"
            )
        )
    }

    @Test("a commented-out set_ verb declares nothing")
    func commentedSetIsInert() {
        #expect(
            !ManagedConfig.declaresManagedSettings(
                "-- KiwiDesk.set_gap_global(10)\n"
            )
        )
    }

    @Test("a set_ call inside a hook body still counts")
    func setInsideHookCounts() {
        // Conservative: a live set_* anywhere means Lua configures
        // tiling, so don't seed over it.
        let source = """
            KiwiDesk.on("space_change", function()
                KiwiDesk.set_mode(1, "bsp")
            end)
            """
        #expect(ManagedConfig.declaresManagedSettings(source))
    }
}
