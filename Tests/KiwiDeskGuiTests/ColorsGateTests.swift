import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// How Advanced Colours GREYS (#678 Phase 3) — split from
/// `ColorsCensusRenderTests` at the 350-line ceiling (§5, split
/// early). That suite pins which rows render where; this one
/// pins which of them are live, and why the page says what it
/// says when they are not.
///
/// The area is the first whose gates all live on ANOTHER page,
/// so the sentence a dimmed row is explained by is part of the
/// behaviour, not decoration.
@Suite("Advanced Colours greying")
struct ColorsGateTests {
    /// The exemption escapes the CONTAINER gate and nothing
    /// else. Asserted over the resolver rather than left to the
    /// view body, because no rendered behaviour distinguishes
    /// the two forms today — nothing in this area is exempt, so
    /// dropping the `||` produced a byte-identical full-suite
    /// result. It is reachable the moment someone adds the first
    /// exemption, and what they would get is a swatch that is
    /// editable, tints nothing, and explains nothing.
    @Test("an exemption escapes the container gate only")
    func exemptionEscapesOnlyTheContainerGate() {
        // `gate` is pure and reads only the flag, so the exempt
        // half is exercised with a key that actually carries it.
        // None is in this area yet — which is the point: the
        // resolver has to be right BEFORE the first one lands.
        let exempt = SettingKey.spaceBar(.spaceBarEnabled)
        let plain = SettingKey.spaceBar(.spaceBarFocusedItemColor)
        #expect(exempt.placement.exemptFromContainerGate)
        #expect(!plain.placement.exemptFromContainerGate)

        // Container gate closed. The plain row greys wholesale
        // and its own predicate stands down, so the hover names
        // the outer reason.
        let closed = AdvancedColorRows.gate(
            allows: false,
            key: plain
        )
        #expect(closed.containerGrey)
        #expect(!closed.rowPredicateLive)

        // Same closed gate, exempt row: the container grey lifts
        // — and its OWN predicate must stay live rather than lift
        // with it. Dropping the `||` flips this one line to
        // false and ships an editable swatch that tints nothing.
        let escaped = AdvancedColorRows.gate(
            allows: false,
            key: exempt
        )
        #expect(!escaped.containerGrey)
        #expect(escaped.rowPredicateLive)

        // Gate open: neither row is touched by either half.
        for key in [plain, exempt] {
            let open = AdvancedColorRows.gate(allows: true, key: key)
            #expect(!open.containerGrey)
            #expect(open.rowPredicateLive)
        }
    }

    /// Advanced Colours exempts no row from a container gate
    /// today. Pinned so that adding one is a conscious edit —
    /// the renderer already honors the flag as data
    /// (`AdvancedColorRows`), so the census is the only half a
    /// future exemption has to touch, and this is what asks
    /// whether it has an argument.
    @Test("no Advanced Colours row escapes its container gate")
    func nothingIsExempt() {
        #expect(
            SettingKey.allCases.filter {
                $0.placement.area == .advancedColours
                    && $0.placement.exemptFromContainerGate
            }
            .isEmpty
        )
    }

    /// The bar groups inherit their block gate from the census
    /// containers the Bars page also gates from — that spanning
    /// is what carries one gate onto both surfaces, so a second
    /// resolver would be the #520 drift. Pin that the resolver
    /// this area uses IS that one.
    @MainActor
    @Test("the bar groups' gates resolve against the draft")
    func barGroupGatesResolve() {
        var settings = TilingSettings()
        settings.spaceBarStyle.enabled = false
        settings.monocle.appBar.enabled = false
        settings.scrolling.appBar.enabled = false
        var gates = AdvancedColorsGates(settings: settings)
        #expect(!gates.bars.allowsEditing(.spaceBar))
        #expect(!gates.bars.allowsEditing(.appBar))

        settings.spaceBarStyle.enabled = true
        settings.monocle.appBar.enabled = true
        gates = AdvancedColorsGates(settings: settings)
        #expect(gates.bars.allowsEditing(.spaceBar))
        #expect(gates.bars.allowsEditing(.appBar))
    }

    /// The off-page gates each pick a sentence, and the OUTERMOST
    /// reason wins — naming the unfocused toggle while the whole
    /// ring is off would send the user to fix the wrong switch.
    @MainActor
    @Test("an off-page gate names the outermost reason")
    func headerHelpPicksTheOuterReason() {
        var settings = TilingSettings()
        settings.borderStyle.enabled = false
        settings.borderStyle.unfocusedEnabled = false
        #expect(
            AdvancedColorsGates(settings: settings)
                .bordersHeaderHelp == AdvancedColorsHelp.borderOff
        )
        settings.borderStyle.enabled = true
        #expect(
            AdvancedColorsGates(settings: settings)
                .bordersHeaderHelp
                == AdvancedColorsHelp.unfocusedOff
        )
        settings.borderStyle.unfocusedEnabled = true
        #expect(
            AdvancedColorsGates(settings: settings)
                .bordersHeaderHelp == nil
        )

        settings.dragGhost.enabled = false
        settings.dragGhost.border = false
        var gates = AdvancedColorsGates(settings: settings)
        #expect(
            gates.dragHeaderHelp(ghost: true)
                == AdvancedColorsHelp.dragOff
        )
        #expect(gates.dragHeaderHelp(ghost: false) == nil)

        // Border and Fill are siblings, not a second level: with
        // both off the column's one live `?` must carry BOTH
        // reasons, or the Fill row sits dimmed and unexplained.
        settings.dragGhost.enabled = true
        settings.dragGhost.fill = false
        gates = AdvancedColorsGates(settings: settings)
        // Exact, not two `contains` checks: those pin presence
        // only, and pass on the two sentences reversed or run
        // together with no separator — visibly broken help.
        #expect(
            gates.dragHeaderHelp(ghost: true)
                == AdvancedColorsHelp.dragBorderOff + "\n"
                + AdvancedColorsHelp.dragFillOff
        )

        settings.dragGhost.border = true
        gates = AdvancedColorsGates(settings: settings)
        #expect(
            gates.dragHeaderHelp(ghost: true)
                == AdvancedColorsHelp.dragFillOff
        )
    }
}
