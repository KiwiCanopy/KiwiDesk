import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Layout Defaults gate resolver (#678 Phase 3, turn 10).
///
/// A census `gate:` is answered by the resolver and never
/// re-implemented beside its row: a renderer whose predicate
/// drifts from the declaration greys the wrong row, and the
/// census's stated owner quietly stops being the owner. These
/// pin each declared gate against a config that satisfies it and
/// one that does not — and pin that the declared set and the
/// resolved set are the same set, so a new gated row cannot land
/// in neither.
@Suite("Layout Defaults gates")
struct LayoutDefaultsGateTests {
    private func gates(
        _ mutate: (inout TilingSettings) -> Void = { _ in }
    ) -> LayoutDefaultsGates {
        var settings = TilingSettings()
        mutate(&settings)
        return LayoutDefaultsGates(settings: settings)
    }

    /// The split is data, so a gated row added to this area
    /// without a resolver arm reds here rather than hitting the
    /// fail-open default at run time.
    @Test("every gated row in the area is accounted for")
    func everyGatedRowIsResolved() {
        let declared = Set(
            SettingKey.allCases.filter {
                $0.placement.area == .layoutDefaults
                    && $0.placement.gate != nil
            }
        )
        #expect(
            declared
                == LayoutDefaultsGates.resolved.union(
                    LayoutDefaultsGates.resolvedElsewhere
                )
        )
        // Both halves pinned, not just their union: an entry
        // parked in `resolvedElsewhere` that the resolver
        // actually answers would claim the opposite of what it
        // does. Trivially true while `resolvedElsewhere` is
        // empty — this is a slot armed for its first entry, not
        // a live net, and reading its green as coverage is the
        // mistake it invites.
        #expect(
            LayoutDefaultsGates.resolved
                .intersection(
                    LayoutDefaultsGates.resolvedElsewhere
                )
                .isEmpty
        )
        // The resolver has no `allowsEditing` arm, so a CONTAINER
        // gate on a layout would grey nothing at all — silently,
        // since the guard above walks row gates only. gui.md's
        // obligation is to converge the resolvers rather than
        // teach this one a second shape; this is what makes that
        // a red test instead of a reviewer's job.
        for mode in LayoutMode.placementTabs {
            #expect(
                LayoutDefaultsRowOrder.container(for: mode)?.gate
                    == nil,
                Comment(
                    rawValue:
                        "\(mode)'s container declares a gate no "
                        + "resolver in this area answers — "
                        + "converge the resolvers first"
                )
            )
        }
        #expect(SettingsContainer.general.gate == nil)
    }

    /// An ungated row is never inert — the guard above says the
    /// resolver knows every gate, and this says it invents none.
    @Test("ungated rows are always live")
    func ungatedRowsStayLive() {
        let context = gates()
        for key in SettingKey.allCases
        where key.placement.area == .layoutDefaults
            && key.placement.gate == nil
        {
            #expect(context.inertReason(for: key) == nil)
        }
    }

    /// Asks the RESOLVED count, not the global (#406): the
    /// per-space master count is a GUI-surfaced override, so a
    /// space running three masters is reading this orientation
    /// whatever the global says — greying it there would lock
    /// the only editor for a value something is using.
    @Test("master orientation follows the resolved master count")
    func masterOrientation() {
        let key = SettingKey.layout(.stackMasterOrientation)
        #expect(
            gates { $0.stack.masterCount = 1 }
                .inertReason(for: key) == .oneMaster
        )
        #expect(
            gates { $0.stack.masterCount = 2 }
                .inertReason(for: key) == nil
        )
        #expect(
            gates {
                $0.stack.masterCount = 1
                var override = StackOverride()
                override.masterCount = 3
                $0.stack.override[SpaceID("1")] = override
            }
            .inertReason(for: key) == nil
        )
        // An override that does not raise the count leaves it
        // inert — the override's presence is not the condition.
        #expect(
            gates {
                $0.stack.masterCount = 1
                var override = StackOverride()
                override.masterRatio = 0.7
                $0.stack.override[SpaceID("1")] = override
            }
            .inertReason(for: key) == .oneMaster
        )
    }

    /// Fill-empty asks the RESOLVED type: a rigid global is
    /// silenced, unless a space overrides back to dynamic, which
    /// makes the global value live for it again (#406/#520).
    @Test("fill empty space asks the resolved grid type")
    func fillEmptySpace() {
        let key = SettingKey.layout(.gridFillEmptySpace)
        #expect(
            gates { $0.grid.type = .dynamic }
                .inertReason(for: key) == nil
        )
        #expect(
            gates { $0.grid.type = .rigid }
                .inertReason(for: key) == .rigidGrid
        )
        #expect(
            gates {
                $0.grid.type = .rigid
                var override = GridOverride()
                override.type = .dynamic
                $0.grid.override[SpaceID("1")] = override
            }
            .inertReason(for: key) == nil
        )
    }

    @Test("grid dimensions ask the resolved auto-size")
    func gridDimensions() {
        for key in [
            SettingKey.layout(.gridColumns),
            SettingKey.layout(.gridRows),
        ] {
            #expect(
                gates { $0.grid.autoSize = false }
                    .inertReason(for: key) == nil
            )
            #expect(
                gates { $0.grid.autoSize = true }
                    .inertReason(for: key) == .autoSizedGrid
            )
            #expect(
                gates {
                    $0.grid.autoSize = true
                    var override = GridOverride()
                    override.autoSize = false
                    $0.grid.override[SpaceID("1")] = override
                }
                .inertReason(for: key) == nil
            )
        }
    }

    @Test("the track limit follows the auto-limit toggle")
    func trackLimit() {
        let key = SettingKey.layout(.trackLimit)
        #expect(
            gates { $0.track.autoTracks = true }
                .inertReason(for: key) == .autoTracks
        )
        #expect(
            gates { $0.track.autoTracks = false }
                .inertReason(for: key) == nil
        )
    }

    @Test("scroll speed follows the scroll animation toggle")
    func scrollSpeed() {
        let key = SettingKey.colours(.animationsScrollSpeedMS)
        #expect(
            gates { $0.animations.onScrolling = false }
                .inertReason(for: key) == .scrollAnimationOff
        )
        #expect(
            gates { $0.animations.onScrolling = true }
                .inertReason(for: key) == nil
        )
    }
}
