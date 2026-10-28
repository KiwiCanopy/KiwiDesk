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
/// declared gate is accounted for. That `LayersCard` CONSULTS the
/// resolver is `ShortcutsOfferDisclosureTests` ▸
/// `cardsOpenOnArrival`'s.
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
    /// keeps the Layers card shut on arrival; nil opens it. This
    /// is the half that reds a renderer pinned
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
            "a configured layer must surface"
        )
        // Presence, not a count: three still reads "exists", and
        // an off-by-one would pass the pair above.
        #expect(
            reason([KeyLayer.defaultName, "resize", "media"]) == nil
        )
        // The rows that exist once a layer does carry the one gate,
        // so they answer together; the strip is the ungated offer
        // (#2654).
        for key: SettingKey in [
            .shortcuts(.layersIcon), .shortcuts(.layersReach),
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
    /// nil, so a further `InertReason` cannot silently stop the
    /// preview caption naming its layer, or shut the Track offer,
    /// for an unrelated cause (architect re-review 2026-09-04).
    /// The Desktop drawer's hold-open (#2655) is no census gate,
    /// but it answers beside them and must not be answered by
    /// them.
    @Test("each named reading answers its own question")
    func namedReadingsAreCaseWise() {
        var layered = config(layers: [KeyLayer.defaultName, "resize"])
        #expect(ShortcutsGates(config: layered).layersExist)
        #expect(
            !ShortcutsGates(config: layered).desktopMovesBound,
            "a layer is not a Desktop binding"
        )
        var desktop = config(layers: [KeyLayer.defaultName])
        desktop.layers[0].bindings = [
            KeyBinding(
                combo: "ctrl+alt+1",
                lua: "KiwiDesk.move_to_desktop(1)",
                kind: .navigation
            )
        ]
        #expect(ShortcutsGates(config: desktop).desktopMovesBound)
        #expect(
            !ShortcutsGates(config: desktop).layersExist,
            "a Desktop binding is not a layer"
        )
        layered.layers[0].bindings = desktop.layers[0].bindings
        #expect(ShortcutsGates(config: layered).layersExist)
        #expect(ShortcutsGates(config: layered).desktopMovesBound)
        // The third reading (#1440) answers neither of the
        // other two questions, and they do not answer it.
        #expect(
            !ShortcutsGates(config: layered).trackInUse,
            "a layer and a Desktop binding are not a track"
        )
        var track = config(layers: [KeyLayer.defaultName])
        track.spaces = ["1"]
        track.spaceModes = ["1": .track]
        #expect(ShortcutsGates(config: track).trackInUse)
        #expect(!ShortcutsGates(config: track).layersExist)
        #expect(!ShortcutsGates(config: track).desktopMovesBound)
        // All cases are spoken for above, the plate switch's
        // greying reasons (#2144, #2460) answering none of the
        // readings; a FIFTH reds here — check what each named
        // reading should answer for it before extending, since
        // none is written against nil.
        #expect(
            Set(ShortcutsGates.InertReason.allCases)
                == [
                    .onlyDefaultLayer, .trackUnused,
                    .appWideLuaOwned, .storedProfilePage,
                ]
        )
    }

    /// The Shortcuts use switch (#2460) greys where `init.lua` owns
    /// the config and on a stored-profile page, Lua first.
    @Test("the Shortcuts use switch's reasons")
    func shortcutBaseReasons() {
        let key = SettingKey.shortcuts(.shortcutBase)
        let base = config(layers: [KeyLayer.defaultName])
        func reason(lua: Bool, stored: Bool) -> ShortcutsGates.InertReason? {
            ShortcutsGates(
                config: base,
                guiManaged: !lua,
                editingStoredProfile: stored
            ).inertReason(for: key)
        }
        #expect(reason(lua: false, stored: false) == nil)
        #expect(reason(lua: false, stored: true) == .storedProfilePage)
        #expect(reason(lua: true, stored: true) == .appWideLuaOwned)
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

    /// The layout plate's switch greys only where init.lua owns
    /// the config (#2144), the one greying gate in this area, and
    /// its row asks this resolver rather than `guiManaged` itself.
    @Test("the plate switch greys under a Lua-owned config")
    func plateSwitchGreysUnderLua() throws {
        let config = GuiConfig()
        let key = SettingKey.shortcuts(.modeCue)
        #expect(
            ShortcutsGates(config: config, guiManaged: true)
                .inertReason(for: key) == nil
        )
        #expect(
            ShortcutsGates(config: config, guiManaged: false)
                .inertReason(for: key) == .appWideLuaOwned
        )
        let file = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Keybindings/"
                    + "LayoutCycleRow.swift"
            )
        let source = SourceScan.stripComments(
            try String(contentsOf: file, encoding: .utf8)
        )
        .split(whereSeparator: \.isWhitespace)
        .joined()
        #expect(
            source.contains(
                "ShortcutsGates(config:model.config,"
                    + "guiManaged:model.guiManaged)"
                    + ".inertReason(for:.shortcuts(.modeCue))"
            ),
            "LayoutCueRow no longer asks ShortcutsGates"
        )
        #expect(source.contains("disabled:luaOwned"))
    }

    /// The Desktop switch cue is app-wide (#2142, #1741): it greys
    /// only where init.lua owns the config, whatever page is
    /// edited, and its row asks this resolver (#2655).
    @Test("the Desktop cue greys only under a Lua-owned config")
    func desktopCueGreysUnderLua() throws {
        let key = SettingKey.shortcuts(.desktopCue)
        for editing in [false, true] {
            #expect(
                ShortcutsGates(
                    config: GuiConfig(),
                    guiManaged: true,
                    editingStoredProfile: editing
                ).inertReason(for: key) == nil
            )
            #expect(
                ShortcutsGates(
                    config: GuiConfig(),
                    guiManaged: false,
                    editingStoredProfile: editing
                ).inertReason(for: key) == .appWideLuaOwned
            )
        }
        let source = SourceScan.stripComments(
            try String(
                contentsOf: SourceScan.repoRoot(from: #filePath)
                    .appendingPathComponent(
                        "Sources/KiwiDesk/Settings/Components/"
                            + "Keybindings/DesktopCueRow.swift"
                    ),
                encoding: .utf8
            )
        )
        .split(whereSeparator: \.isWhitespace)
        .joined()
        #expect(
            source.contains(
                "ShortcutsGates(config:model.config,"
                    + "guiManaged:model.guiManaged)"
                    + ".inertReason(for:.shortcuts(.desktopCue))"
            )
        )
        #expect(source.contains("disabled:luaOwned"))
        #expect(
            source.contains(
                "ifluaOwned{Text(GeneralGateHelp.sentence(for:.luaOwned))"
            )
        )
    }
}
