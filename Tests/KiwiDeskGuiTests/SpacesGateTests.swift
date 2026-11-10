import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Spaces & Layouts gate resolver (#678 Phase 3, turn 8).
///
/// A census `gate:` is answered by the resolver and never
/// re-implemented beside its row: a renderer whose predicate
/// drifts from the declaration greys the wrong row, and the
/// census's stated owner quietly stops being the owner. These pin
/// each declared gate against a config that satisfies it and one
/// that does not — and pin that the declared set and the resolved
/// set are the same set, so a new gated row cannot land in
/// neither.
///
/// Unlike the other area resolvers this one is PER INSTANCE (one
/// space, its active layout), so every case is built for a
/// specific space and the override predicates read that space's
/// resolved params (#406/#520): a control the global would silence
/// is still live for a space that overrides it.
@Suite("Spaces & Layouts gates")
struct SpacesGateTests {
    private let space = SpaceID("1")

    private func gates(
        mode: LayoutMode = .stack,
        _ mutate: (inout TilingSettings) -> Void = { _ in }
    ) -> SpacesGates {
        var settings = TilingSettings()
        mutate(&settings)
        return SpacesGates(
            settings: settings,
            space: space,
            mode: mode
        )
    }

    /// The declared-vs-answered split, read off the census: a new
    /// gated ROW in this area that lands in neither set reds here
    /// rather than failing open at run time.
    @Test("every gated row in the area is accounted for")
    func everyGatedRowIsResolved() {
        let declared = Set(
            SettingKey.allCases.filter {
                $0.placement.area == .spacesAndLayouts
                    && $0.placement.gate != nil
            }
        )
        #expect(
            declared
                == SpacesGates.resolved.union(
                    SpacesGates.resolvedElsewhere
                )
        )
        // Both halves pinned, not just their union — an entry
        // parked in `resolvedElsewhere` that the resolver actually
        // answers would claim the opposite of what it does.
        // Trivially true while `resolvedElsewhere` is empty: a slot
        // armed for its first entry, not a live net.
        #expect(
            SpacesGates.resolved
                .intersection(SpacesGates.resolvedElsewhere)
                .isEmpty
        )
    }

    /// No container in this area carries a gate, so the resolver
    /// answers only ROW gates — a CONTAINER gate here would grey a
    /// whole card with nothing to resolve it. Data, so it reds the
    /// day one is added rather than at a reviewer's discretion.
    @Test("the area carries no container gate")
    func noContainerGate() {
        let gatedContainers = Set(
            SettingKey.allCases
                .filter { $0.placement.area == .spacesAndLayouts }
                .compactMap { $0.placement.container }
                .filter { $0.gate != nil }
        )
        #expect(gatedContainers.isEmpty)
    }

    /// An ungated row is never inert — the guard above says the
    /// resolver knows every gate, and this says it invents none.
    /// Keeps the `default:` arm unreachable rather than merely
    /// believed to be.
    @Test("ungated rows stay live")
    func ungatedRowsStayLive() {
        let context = gates()
        for key in SettingKey.allCases
        where key.placement.area == .spacesAndLayouts
            && key.placement.gate == nil
        {
            #expect(context.inertReason(for: key) == nil)
        }
    }

    /// The reset action greys once the active layout has no set
    /// override fields for the space.
    @Test("reset greys while the active layout has no overrides")
    func resetGreysWithoutOverrides() {
        let key = SettingKey.spaces(.spaceOverrideResetActive)
        #expect(
            gates(mode: .stack).inertReason(for: key)
                == .noOverrides
        )
        #expect(
            gates(mode: .stack) {
                var override = StackOverride()
                override.masterCount = 2
                $0.stack.override[space] = override
            }
            .inertReason(for: key) == nil
        )
        // Counts the ACTIVE layout only: an override on another
        // layout leaves this action dead.
        #expect(
            gates(mode: .grid) {
                var override = StackOverride()
                override.masterCount = 2
                $0.stack.override[space] = override
            }
            .inertReason(for: key) == .noOverrides
        )
    }

    /// Master orientation asks the RESOLVED master count (#406): a
    /// space running several masters reads it whatever the global
    /// says, so greying it there would lock the only editor for a
    /// value something uses.
    @Test("master orientation follows the resolved master count")
    func masterOrientation() {
        let key = SettingKey.layout(.stackOverrideMasterOrientation)
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
                $0.stack.override[space] = override
            }
            .inertReason(for: key) == nil
        )
    }

    /// Fill-empty asks the RESOLVED grid type: a rigid global is
    /// silenced, unless the space overrides back to dynamic.
    @Test("fill empty cells asks the resolved grid type")
    func fillEmptyCells() {
        let key = SettingKey.layout(.gridOverrideFillEmptyCells)
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
                $0.grid.override[space] = override
            }
            .inertReason(for: key) == nil
        )
    }

    /// The Columns/Rows steppers ask the RESOLVED auto-size: on for
    /// the space silences both, unless the space overrides it off.
    @Test("grid dimensions ask the resolved auto-size")
    func gridDimensions() {
        for key in [
            SettingKey.layout(.gridOverrideColumns),
            SettingKey.layout(.gridOverrideRows),
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
                    $0.grid.override[space] = override
                }
                .inertReason(for: key) == nil
            )
        }
    }

    /// The track limit follows the RESOLVED auto-tracks toggle.
    @Test("the track limit follows the resolved auto-tracks")
    func trackLimit() {
        let key = SettingKey.layout(.trackOverrideLimit)
        #expect(
            gates { $0.track.autoTracks = true }
                .inertReason(for: key) == .autoTracks
        )
        #expect(
            gates { $0.track.autoTracks = false }
                .inertReason(for: key) == nil
        )
        #expect(
            gates {
                $0.track.autoTracks = true
                var override = TrackOverride()
                override.autoTracks = false
                $0.track.override[space] = override
            }
            .inertReason(for: key) == nil
        )
    }

    /// The gaps row asks both inputs (#3123): Monocle's global
    /// "Maximize windows" and the Space's own layout. Floating
    /// keeps its own reason, whatever the switch says.
    @MainActor
    @Test("gaps grey while Monocle maximizes")
    func gapsGreyWhileMonocleMaximizes() {
        let key = SettingKey.gaps(.perSpaceOverride)
        let on: (inout TilingSettings) -> Void = {
            $0.monocle.maximizeWindows = true
        }
        #expect(
            gates(mode: .monocle, on).inertReason(for: key)
                == .monocleMaximizes
        )
        #expect(
            gates(mode: .monocle) {
                $0.monocle.maximizeWindows = false
            }
            .inertReason(for: key) == nil
        )
        for mode in LayoutMode.allCases
        where mode != .monocle && mode != .floating {
            #expect(gates(mode: mode, on).inertReason(for: key) == nil)
        }
        #expect(
            gates(mode: .floating, on).inertReason(for: key)
                == .floatingPlacesNone
        )
    }

    /// Each reason's owners are owners the census names for its
    /// row, and a reason that names them all takes the row's
    /// census channel (#3123). A row whose owners span two
    /// destinations takes its channel per reason.
    @Test("each reason's owners agree with the census")
    func reasonsAgreeWithTheCensus() {
        for reason in SpacesGates.InertReason.allCases {
            let gate = reason.row.placement.gate
            let declared = Set(gate?.settings ?? [])
            #expect(
                Set(reason.owners).isSubset(of: declared),
                "\(reason) names an owner its row's gate does not"
            )
            guard !reason.owners.isEmpty,
                Set(reason.owners) == declared
            else { continue }
            #expect(
                reason.isRemote
                    == (GateReasonPlacement.channel(reason.row)
                        == .remote),
                "\(reason) disagrees with its row's channel"
            )
        }
        #expect(
            Set(SpacesGates.InertReason.allCases.map(\.row))
                .isSubset(of: SpacesGates.resolved)
        )
    }

    /// Every reason renders a distinct, non-empty sentence: a
    /// collapsed pair would send the reader to the wrong fix.
    @MainActor
    @Test("each inert reason renders its own sentence")
    func eachReasonHasItsOwnSentence() {
        let all = SpacesGates.InertReason.allCases
        let sentences = all.map(SpacesGateHelp.sentence)
        for sentence in sentences {
            #expect(!sentence.isEmpty)
        }
        #expect(Set(sentences).count == all.count)
    }
}
