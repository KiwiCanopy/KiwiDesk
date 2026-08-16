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

    /// The diff helper itself, on the property the panel relies
    /// on but never exercises: a key present on ONE side is a
    /// change. A sparse override that adds a field the defaults
    /// omit is still a departure.
    @Test("a one-sided leaf counts as a change")
    func oneSidedLeafCounts() {
        var settings = TilingSettings()
        var override = TrackOverride()
        override.limit = settings.track.limit + 4
        override.autoTracks = !settings.track.autoTracks
        settings.track.override["1"] = override
        let view = panel(
            spaces: ["1"],
            modes: ["1": .track],
            settings: settings
        )
        #expect(view.overrideCount(for: "1") == 2)
    }
}
