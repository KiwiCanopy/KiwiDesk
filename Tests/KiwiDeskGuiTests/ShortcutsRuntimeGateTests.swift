import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The census `.runtime` gates for Shortcuts, and the tier that
/// depends on them (#678 Phase 3).
///
/// This suite exists because `guard-prover` found the invariant
/// it covers held by NOTHING. Three separate violations passed
/// the whole 2480-test suite: deleting the `layersExist` gate
/// from the census while keeping the `.immediate` tier, pinning
/// the renderer's predicate to `false` (which hides a user's
/// configured layers — the exact defect the area shipped once),
/// and pinning it to `true` (which stops withholding the offer
/// to create the first layer). The other Shortcuts suites cover
/// placement bookkeeping — which key sits in which container at
/// which tier — and say nothing about whether any of it reaches
/// the screen.
///
/// So this holds the two halves that were missing: that an
/// `.immediate` row carries the gate its tier's meaning depends
/// on, and that the gate's predicate answers correctly for a
/// config on each side of it.
@Suite("Shortcuts runtime gates")
struct ShortcutsRuntimeGateTests {
    private func config(layers: [String]) -> GuiConfig {
        var c = GuiConfig()
        c.layers = layers.map { KeyLayer(name: $0) }
        return c
    }

    /// `.immediate` means "surfaces without disclosure the moment
    /// its GATE allows". Without a gate the tier says nothing at
    /// all, so the declaration would be decorative — and deleting
    /// the gate was one of the three silent mutations.
    ///
    /// Derived over the whole census, not restated: a second
    /// `.immediate` row placed anywhere inherits this the day it
    /// lands.
    @Test("every .immediate row carries a runtime gate")
    func immediateRowsAreGated() {
        let immediate = SettingKey.allCases.filter {
            $0.placement.tier == .immediate
        }
        // Vacuity: the tier must be in use, or this sweeps an
        // empty set and passes having looked at nothing.
        #expect(!immediate.isEmpty)
        for key in immediate {
            guard case .runtime = key.placement.gate else {
                Issue.record(
                    Comment(
                        rawValue: "\(key.id) is .immediate with "
                            + "no runtime gate — its tier has no "
                            + "meaning without one"
                    )
                )
                continue
            }
        }
    }

    /// The predicate itself, on each side of the boundary. This
    /// is the half that reds a renderer pinned to `false` or
    /// `true`, because `LayersCard` now asks this rather than
    /// re-deriving the condition inline.
    @Test("layersExist is false for default alone, true beyond it")
    func layersExistBoundary() {
        #expect(
            !ShortcutsRuntimeGate.isSatisfied(
                .layersExist,
                in: config(layers: [KeyLayer.defaultName])
            ),
            "only default configured: the card is the offer"
        )
        #expect(
            ShortcutsRuntimeGate.isSatisfied(
                .layersExist,
                in: config(layers: [KeyLayer.defaultName, "resize"])
            ),
            "a configured layer must surface in both modes"
        )
        // Three layers is still "exists" — the gate is presence,
        // not a count, and an off-by-one would pass the pair
        // above.
        #expect(
            ShortcutsRuntimeGate.isSatisfied(
                .layersExist,
                in: config(
                    layers: [KeyLayer.defaultName, "resize", "media"]
                )
            )
        )
    }

    /// Every runtime gate the Shortcuts area declares is either
    /// resolved from the config here, or deliberately resolved
    /// elsewhere — never simply unhandled.
    ///
    /// Derived from the census, so a new `.runtime` gate placed
    /// in this area lands in neither set and reds. That is what
    /// keeps `isSatisfied`'s `preconditionFailure` unreachable in
    /// production rather than merely believed to be.
    @Test("every Shortcuts runtime gate has a declared resolver")
    func everyRuntimeGateIsAccountedFor() {
        var declared: Set<SettingRuntimeGate> = []
        for key in SettingKey.allCases
        where key.placement.area == .shortcuts {
            if case .runtime(let gate) = key.placement.gate {
                declared.insert(gate)
            }
        }
        #expect(!declared.isEmpty)
        let accounted =
            ShortcutsRuntimeGate.resolved
            .union(ShortcutsRuntimeGate.resolvedElsewhere)
        #expect(
            declared.isSubset(of: accounted),
            Comment(
                rawValue: "unaccounted gates: "
                    + "\(declared.subtracting(accounted))"
            )
        )
        // And the reverse: a resolver for a gate the area no
        // longer declares is dead code claiming coverage.
        #expect(accounted.isSubset(of: declared))
    }
}
