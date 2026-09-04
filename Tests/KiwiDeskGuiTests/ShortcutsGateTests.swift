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

    /// The two named readings, and that they stay independent.
    /// Each is written against its OWN case rather than against
    /// nil, so a third `InertReason` cannot silently stop the
    /// preview caption naming its layer, or shut the Desktop
    /// offer, for an unrelated cause (architect re-review
    /// 2026-09-04). With two live cases this is a real test
    /// rather than the tripwire it started as.
    @Test("each named reading answers its own question")
    func namedReadingsAreCaseWise() {
        var layered = config(layers: [KeyLayer.defaultName, "resize"])
        #expect(ShortcutsGates(config: layered).layersExist)
        #expect(
            !ShortcutsGates(config: layered).desktopBindingsExist,
            "a layer is not a Desktop binding"
        )
        var desktop = config(layers: [KeyLayer.defaultName])
        desktop.layers[0].bindings = [
            KeyBinding(
                combo: "ctrl+alt+1",
                lua: "KiwiDesk.focus_desktop(1)",
                kind: .navigation
            )
        ]
        #expect(ShortcutsGates(config: desktop).desktopBindingsExist)
        #expect(
            !ShortcutsGates(config: desktop).layersExist,
            "a Desktop binding is not a layer"
        )
        layered.layers[0].bindings = desktop.layers[0].bindings
        #expect(ShortcutsGates(config: layered).layersExist)
        #expect(ShortcutsGates(config: layered).desktopBindingsExist)
        // Both cases are spoken for above; a THIRD reds here —
        // check what each named reading should answer for it
        // before extending, since neither is written against nil.
        #expect(
            Set(ShortcutsGates.InertReason.allCases)
                == [.onlyDefaultLayer, .noDesktopBinding]
        )
    }

    /// The Desktop offer's boundary (#1125). The seed authors no
    /// Desktop binding, so a fresh install answers "withheld" —
    /// the row is an offer, not a setting.
    @Test("a bound Desktop shortcut brings its families to rest")
    func desktopBindingBoundary() {
        func reason(
            _ bindings: [KeyBinding]
        ) -> ShortcutsGates.InertReason? {
            var config = GuiConfig()
            config.layers = [
                KeyLayer(
                    name: KeyLayer.defaultName,
                    bindings: bindings
                )
            ]
            return ShortcutsGates(config: config)
                .inertReason(for: .shortcuts(.focusDesktop))
        }
        func binding(
            _ combo: String,
            _ lua: String
        ) -> KeyBinding {
            KeyBinding(combo: combo, lua: lua, kind: .navigation)
        }
        #expect(reason([]) == .noDesktopBinding)
        // A Space verb is not a Desktop verb — the two families
        // sit side by side in the same group, and the offer must
        // not open on the wrong one.
        #expect(
            reason([binding("ctrl+alt+1", "KiwiDesk.focus_space('1')")])
                == .noDesktopBinding
        )
        #expect(
            reason([
                binding("ctrl+alt+1", "KiwiDesk.focus_desktop(1)")
            ]) == nil
        )
        // …and the two other verbs count for the same offer.
        #expect(
            reason([
                binding(
                    "ctrl+alt+2",
                    "KiwiDesk.move_to_desktop(2)"
                )
            ]) == nil
        )
        // An UNRECORDED row is not a binding: clearing a row
        // deletes it, so an empty combo is one nobody finished.
        #expect(
            reason([binding("", "KiwiDesk.focus_desktop(1)")])
                == .noDesktopBinding
        )
    }

    /// The offer is the AREA's, not the layer's: the rows are per
    /// layer, but a user who bound a Desktop verb anywhere has
    /// met the concept, and hiding the families while they edit
    /// another layer would make the offer flicker under the
    /// strip.
    @Test("a binding in any layer opens the offer")
    func desktopBindingCountsAcrossLayers() {
        var config = GuiConfig()
        config.layers = [
            KeyLayer(name: KeyLayer.defaultName),
            KeyLayer(
                name: "media",
                bindings: [
                    KeyBinding(
                        combo: "ctrl+alt+3",
                        lua: "KiwiDesk.move_to_desktop_and_follow(3)",
                        kind: .navigation
                    )
                ]
            ),
        ]
        for key: SettingKey in [
            .shortcuts(.focusDesktop), .shortcuts(.moveToDesktop),
            .shortcuts(.moveToDesktopFollow),
        ] {
            #expect(
                ShortcutsGates(config: config)
                    .inertReason(for: key) == nil
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

    /// A SURFACING gate leaves nothing behind to prove it was
    /// drawn: the resolver's own suite, the census parity and
    /// the family expansion all pass whether or not the `if`
    /// was ever written (the Monitors lesson). So the branches
    /// are needled through their BODIES, keyed on the use site.
    @Test("the Desktop offer draws both of its branches")
    func desktopOfferBranchesAreDrawn() throws {
        let file = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/"
                    + "Keybindings/DesktopShortcutsOffer.swift"
            )
        let source = SourceScan.stripComments(
            try String(contentsOf: file, encoding: .utf8)
        )
        .split(whereSeparator: \.isWhitespace)
        .joined()
        // The verdict is the resolver's, never counted here.
        #expect(
            source.contains(
                "ShortcutsGates(config:model.config)"
                    + ".inertReason(for:$0)==nil"
            )
        )
        // At rest when bound…
        #expect(source.contains("ifbound{families}else{"))
        // …behind the drawer when not, and the drawer is the
        // door: an offer that draws nothing here withholds a
        // capability with no way back to it.
        #expect(
            source.contains(
                "SettingsDisclosure(drawer,isExpanded:$expanded)"
                    + "{families}"
            )
        )
        // …and neither branch draws while the families are
        // empty, or the door opens on nothing.
        #expect(source.contains("ifhasRows{"))
        // Both groups mount it, with their own family list.
        let groups = SourceScan.stripComments(
            try String(
                contentsOf: SourceScan.repoRoot(from: #filePath)
                    .appendingPathComponent(
                        "Sources/KiwiDesk/Settings/Components/"
                            + "Keybindings/KeybindingGroups.swift"
                    ),
                encoding: .utf8
            )
        )
        .split(whereSeparator: \.isWhitespace)
        .joined()
        #expect(
            groups.occurrences(of: "DesktopShortcutsOffer(") == 2
        )
        #expect(
            groups.contains(
                "keys:ShortcutsRowOrder.focusDesktops"
            )
        )
        #expect(
            groups.contains(
                "keys:ShortcutsRowOrder.moveWindowsDesktops"
            )
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
                "ShortcutsGates(config:model.config).layersExist"
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
