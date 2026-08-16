import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Spaces panel's caption arithmetic (#794).
///
/// The panel says how many settings a Space overrides, and the
/// number is DERIVED — `TilingSettingsDiff` counts the leaves that
/// differ between the global settings and
/// `TilingSettings.resolved(for:activeMode:)`. A hand-listed set
/// of overridable fields would be a third mirror of one the engine
/// and the per-space editor already carry, which
/// `parity-tests.md` rules against past two.
///
/// **Asserted as arithmetic, never as a source needle.** The
/// caption could call the resolver and render a constant and every
/// scan would pass — the failure `LayoutSchematicCountTests`
/// records for its own lane. So the count is read directly, over
/// settings built here.
@Suite("Spaces panel preview")
@MainActor
struct SpacesPanelPreviewTests {
    private func panel(
        spaces: [SpaceID],
        modes: [SpaceID: LayoutMode] = [:],
        settings: TilingSettings = TilingSettings()
    ) -> SpacesPanelPreview {
        let model = makeTestModel()
        model.config.spaces = spaces
        model.config.spaceModes = modes
        model.config.settings = settings
        return SpacesPanelPreview(model: model)
    }

    /// A Space with no overrides departs from nothing, whatever
    /// its layout — the caption's "follows the layout defaults"
    /// arm has to be reachable, and reachable for every mode
    /// rather than only the default one.
    @Test("a Space with no overrides counts zero")
    func cleanSpaceCountsZero() {
        for mode in LayoutMode.allCases {
            let view = panel(
                spaces: ["1"],
                modes: ["1": mode]
            )
            #expect(
                view.overrideCount(for: "1") == 0,
                Comment(
                    rawValue:
                        "\(mode) reported an override on a "
                        + "Space that sets none"
                )
            )
        }
    }

    /// One overridden field counts one — and the count follows
    /// the ACTIVE layout, so an override stored for a layout the
    /// Space is not using is not a departure from what it draws.
    @Test("the count follows the active layout's overrides")
    func countIsPerActiveLayout() {
        var settings = TilingSettings()
        var override = StackOverride()
        override.masterCount = settings.stack.masterCount + 2
        settings.stack.override["1"] = override
        let onStack = panel(
            spaces: ["1"],
            modes: ["1": .stack],
            settings: settings
        )
        #expect(onStack.overrideCount(for: "1") >= 1)
        // The same settings, with the Space on BSP: the stack
        // override is stored but not in force, so the picture is
        // the defaults and the caption must say so.
        let onBsp = panel(
            spaces: ["1"],
            modes: ["1": .bsp],
            settings: settings
        )
        #expect(onBsp.overrideCount(for: "1") == 0)
    }

    /// Two changed fields count two. Guards the LEAF walk rather
    /// than a top-level key compare — a diff that collapsed a
    /// layout's whole sub-object into one change would report 1
    /// here and read plausibly.
    @Test("two overridden fields count two")
    func leavesAreCountedIndividually() {
        var settings = TilingSettings()
        var override = StackOverride()
        override.masterCount = settings.stack.masterCount + 1
        override.masterRatio = settings.stack.masterRatio / 2
        settings.stack.override["1"] = override
        let view = panel(
            spaces: ["1"],
            modes: ["1": .stack],
            settings: settings
        )
        #expect(view.overrideCount(for: "1") == 2)
    }

    /// Floating resolves to nothing and draws nothing, so it can
    /// never report an override — the arm that would otherwise
    /// caption a picture the panel does not draw.
    @Test("Floating never reports an override")
    func floatingCountsZero() {
        var settings = TilingSettings()
        var override = StackOverride()
        override.masterCount = settings.stack.masterCount + 3
        settings.stack.override["1"] = override
        let view = panel(
            spaces: ["1"],
            modes: ["1": .floating],
            settings: settings
        )
        #expect(view.overrideCount(for: "1") == 0)
    }

    /// **Every layout**, not just the convenient ones.
    ///
    /// The suite originally sampled Stack and Track, and the one
    /// case where the Swift name and the wire key diverge —
    /// Scrolling, which encodes as `scroll` — was the one it did
    /// not reach. So a Scrolling Space with overrides captioned
    /// "follows the layout defaults" and every test passed
    /// (architect review, 2026-08-16). Sweeping `allCases` is
    /// what makes a name divergence in a seventh layout this
    /// suite's problem rather than the next reviewer's.
    @Test("every layout's overrides are counted")
    func everyLayoutCounts() {
        for mode in LayoutMode.allCases where mode != .floating {
            var settings = TilingSettings()
            let before = settings
            apply(anOverrideFor: mode, to: &settings)
            #expect(
                settings != before,
                Comment(
                    rawValue: "\(mode) fixture set nothing"
                )
            )
            let view = panel(
                spaces: ["1"],
                modes: ["1": mode],
                settings: settings
            )
            #expect(
                view.overrideCount(for: "1") >= 1,
                Comment(
                    rawValue:
                        "\(mode) overrides went uncounted — its "
                        + "encoded subtree is not being found"
                )
            )
        }
    }

    /// One sparse override per layout, set through each layout's
    /// own override struct.
    private func apply(
        anOverrideFor mode: LayoutMode,
        to settings: inout TilingSettings
    ) {
        switch mode {
        case .bsp:
            var o = BspOverride()
            o.splitRatioH = settings.bsp.splitRatioH / 2
            settings.bsp.override["1"] = o
        case .stack:
            var o = StackOverride()
            o.masterCount = settings.stack.masterCount + 1
            settings.stack.override["1"] = o
        case .scrolling:
            var o = ScrollingOverride()
            o.anchor =
                settings.scrolling.anchor == .center
                ? .start : .center
            settings.scrolling.override["1"] = o
        case .monocle:
            var o = MonocleOverride()
            o.orientation =
                settings.monocle.orientation == .horizontal
                ? .vertical : .horizontal
            settings.monocle.override["1"] = o
        case .grid:
            var o = GridOverride()
            o.columns = settings.grid.columns + 1
            settings.grid.override["1"] = o
        case .track:
            var o = TrackOverride()
            o.limit = settings.track.limit + 1
            settings.track.override["1"] = o
        case .floating:
            break
        }
    }

    /// The caption and the editor's header count the SAME thing.
    ///
    /// They are two numbers about one Space on one screen, and
    /// they disagreed: the header renders
    /// `overrideFieldCount` (fields SET) while the caption's
    /// first cut counted leaves that DIFFER. `overrideToggle`
    /// seeds a newly ticked override with the global value, so
    /// the first click on any checkbox made the header say
    /// "1 of 6 set" beside "follows the layout defaults" (code
    /// review, 2026-08-16). Asserted against the seam the header
    /// itself reads, so the two cannot drift apart again.
    @Test("the caption counts what the header counts")
    func captionAgreesWithTheHeader() {
        for mode in LayoutMode.allCases where mode != .floating {
            var settings = TilingSettings()
            apply(anOverrideFor: mode, to: &settings)
            let view = panel(
                spaces: ["1"],
                modes: ["1": mode],
                settings: settings
            )
            #expect(
                view.overrideCount(for: "1")
                    == settings.overrideFieldCount(mode, for: "1"),
                Comment(
                    rawValue:
                        "\(mode): the caption and the header "
                        + "count differently"
                )
            )
        }
    }

    /// A ticked-but-unchanged override still counts. This is the
    /// exact shape that made the two numbers disagree — the
    /// checkbox seeds the global value, so the field is SET and
    /// nothing DIFFERS.
    @Test("a ticked override counts before it is changed")
    func seededOverrideCounts() {
        var settings = TilingSettings()
        var override = StackOverride()
        // Seeded with the global, the way `overrideToggle` does.
        override.masterCount = settings.stack.masterCount
        settings.stack.override["1"] = override
        let view = panel(
            spaces: ["1"],
            modes: ["1": .stack],
            settings: settings
        )
        #expect(view.overrideCount(for: "1") == 1)
    }
}
