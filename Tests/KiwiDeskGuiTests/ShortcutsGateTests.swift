import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The census gates for the Shortcuts area, resolved through
/// `ShortcutsGates` (#678 Phase 3; folded onto the reason-case
/// shape 2026-08-03).
///
/// This suite exists because `guard-prover` found the invariant it
/// covers held by NOTHING. Three separate violations passed the
/// whole suite: deleting the `.layersExist` gate from the census
/// while keeping the `.immediate` tier, pinning the renderer's
/// predicate to `false` (which hides a user's configured layers —
/// the exact defect the area shipped once), and pinning it to
/// `true` (which stops withholding the offer to create the first
/// layer).
///
/// So it holds the halves that were missing: that an `.immediate`
/// row carries the gate its tier's meaning depends on, that the
/// resolver answers on each side of the boundary, that every
/// declared gate is accounted for, and that `LayersCard` actually
/// CONSULTS the resolver rather than re-deriving it — the
/// dead-resolver trap the General lane shipped.
@Suite("Shortcuts gates")
struct ShortcutsGateTests {
    private func config(layers: [String]) -> GuiConfig {
        var c = GuiConfig()
        c.layers = layers.map { KeyLayer(name: $0) }
        return c
    }

    /// `.immediate` means "surfaces without disclosure the moment
    /// its GATE allows". Without a gate the tier says nothing at
    /// all, so the declaration would be decorative. Derived over
    /// the whole census, not restated: a second `.immediate` row
    /// placed anywhere inherits this the day it lands.
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

    /// The resolver on each side of the boundary. A non-nil reason
    /// WITHHOLDS the Layers rows behind the offer; nil surfaces
    /// them at rest. This is the half that reds a renderer pinned
    /// to a constant, because `LayersCard` now asks this rather
    /// than re-deriving the condition inline.
    @Test("layer presence flips the resolver's reason")
    func layerPresenceBoundary() {
        func reason(
            _ layers: [String]
        ) -> ShortcutsGates.InertReason? {
            ShortcutsGates(config: config(layers: layers))
                .inertReason(for: .shortcuts(.switchToLayer))
        }
        #expect(
            reason([KeyLayer.defaultName]) == .onlyDefaultLayer,
            "only default configured: the card is the offer"
        )
        #expect(
            reason([KeyLayer.defaultName, "resize"]) == nil,
            "a configured layer must surface in both modes"
        )
        // Presence, not a count: three still reads "exists", and
        // an off-by-one would pass the pair above.
        #expect(
            reason([KeyLayer.defaultName, "resize", "media"]) == nil
        )
        // All three Layers rows carry the one gate, so they answer
        // together — a resolver that only knew `switchToLayer`
        // would leave the other two unaccounted below.
        for key: SettingKey in [
            .shortcuts(.layers), .shortcuts(.layersIcon),
            .shortcuts(.switchToLayer),
        ] {
            #expect(
                ShortcutsGates(
                    config: config(layers: [KeyLayer.defaultName])
                )
                .inertReason(for: key) == .onlyDefaultLayer
            )
        }
    }

    /// Every gated row the area declares is either resolved from
    /// the config here or deliberately resolved elsewhere — never
    /// simply unhandled. Derived from the census, so a new gate
    /// lands in neither set and reds, which keeps `inertReason`'s
    /// fail-open arm unreachable rather than merely believed to be.
    @Test("every gated Shortcuts row has a declared resolver")
    func everyGatedRowIsResolved() {
        let gated = Set(
            SettingKey.allCases.filter {
                $0.placement.area == .shortcuts
                    && $0.placement.gate != nil
            }
        )
        #expect(!gated.isEmpty)
        #expect(
            gated
                == ShortcutsGates.resolved
                .union(ShortcutsGates.resolvedElsewhere)
        )
        #expect(
            ShortcutsGates.resolved
                .isDisjoint(with: ShortcutsGates.resolvedElsewhere)
        )
    }

    /// `LayersCard` must ASK the resolver, not re-derive the
    /// predicate inline — the dead-resolver trap General shipped
    /// (built in tests, re-derived in the view; both reviewers
    /// caught it, guard-prover did not, because a behaviour test
    /// reds on the resolver alone). Whitespace-free so the needle
    /// survives the formatter wrapping the call across lines.
    @Test("LayersCard consults the resolver")
    func layersCardConsultsTheResolver() throws {
        let file = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Sections/"
                    + "LayersCard.swift"
            )
        let source = SourceScan.stripComments(
            try String(contentsOf: file, encoding: .utf8)
        )
        .split(whereSeparator: \.isWhitespace)
        .joined()
        #expect(
            source.contains(
                "ShortcutsGates(config:model.config)"
                    + ".inertReason(for:.shortcuts(.switchToLayer))"
            ),
            Comment(
                rawValue:
                    "LayersCard no longer asks ShortcutsGates — the "
                    + "layers gate went hand-rolled, the "
                    + "dead-resolver trap"
            )
        )
    }
}
