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
    /// The exemption escapes the shelf's block gate and nothing
    /// else, asserted over the verdict because nothing in this
    /// area is exempt yet — so the first exemption gets a swatch
    /// that keeps its own reason rather than one that tints
    /// nothing and explains nothing.
    @Test("an exemption escapes the container gate only")
    func exemptionEscapesOnlyTheContainerGate() {
        let exempt = SettingKey.borders(.borderEnabled)
        let plain = SettingKey.kiwishelf(.itemColor)
        #expect(exempt.placement.exemptFromContainerGate)
        #expect(!plain.placement.exemptFromContainerGate)
        #expect(AdvancedColorsGates.takesShelfGate(plain))
        #expect(!AdvancedColorsGates.takesShelfGate(exempt))
        // Window rows never take the shelf's gate.
        #expect(
            !AdvancedColorsGates.takesShelfGate(
                .borders(.borderFocusedColor)
            )
        )
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
        #expect(
            gates.bars.containerReason(for: .spaceBar) == .spaceBarOff
        )
        #expect(
            gates.bars.containerReason(for: .appBar) == .noBarShown
        )

        settings.spaceBarStyle.enabled = true
        settings.monocle.appBar.enabled = true
        gates = AdvancedColorsGates(settings: settings)
        #expect(gates.bars.containerReason(for: .spaceBar) == nil)
        #expect(gates.bars.containerReason(for: .appBar) == nil)
    }

    /// The off-page gates each pick a sentence, and the OUTERMOST
    /// reason wins — naming the unfocused toggle while the whole
    /// ring is off would send the user to fix the wrong switch.
    @MainActor
    @Test("an off-page gate names the outermost reason")
    func rowHelpPicksTheOuterReason() {
        let unfocused = SettingKey.borders(.borderUnfocusedColor)
        let focusedItem = SettingKey.spaceBar(.spaceBarFocusedItemColor)
        var settings = TilingSettings()
        settings.borderStyle.enabled = false
        settings.borderStyle.unfocusedEnabled = false
        var gates = AdvancedColorsGates(settings: settings)
        #expect(
            gates.verdict(for: unfocused)
                == ColorRowVerdict(
                    help: AdvancedColorsHelp.borderOff,
                    link: .page(.gapsAndBorders)
                )
        )
        // Ring on, unfocused off: the row's own sentence (#1310).
        settings.borderStyle.enabled = true
        gates = AdvancedColorsGates(settings: settings)
        #expect(
            gates.verdict(for: unfocused)?.link
                == .ownSentence(.gapsAndBorders)
        )
        settings.borderStyle.unfocusedEnabled = true
        #expect(
            AdvancedColorsGates(settings: settings)
                .verdict(for: unfocused) == nil
        )

        // The focused-item row: every bar off names the shelf;
        // the Space Bar off with an App Bar on names the Space
        // Bar's switch, never the glyph style; the bar on with
        // App icons takes the row's own sentence; Symbols draws.
        settings.spaceBarStyle.enabled = false
        settings.monocle.appBar.enabled = false
        settings.scrolling.appBar.enabled = false
        settings.kiwishelf.iconSource = .appImage
        settings.spaceBarStyle.showFrontApp = false
        #expect(
            AdvancedColorsGates(settings: settings)
                .verdict(for: focusedItem)?.help
                == AdvancedColorsHelp.kiwishelfOff
        )
        settings.monocle.appBar.enabled = true
        #expect(
            AdvancedColorsGates(settings: settings)
                .verdict(for: focusedItem)
                == ColorRowVerdict(
                    help: BarsGateHelp.sentence(for: .spaceBarOff),
                    link: .page(.bars)
                )
        )
        settings.spaceBarStyle.enabled = true
        #expect(
            AdvancedColorsGates(settings: settings)
                .verdict(for: focusedItem)
                == ColorRowVerdict(
                    help: AdvancedColorsHelp.focusedItemHelp,
                    link: .ownSentence(.bars)
                )
        )
        settings.kiwishelf.iconSource = .appFont
        #expect(
            AdvancedColorsGates(settings: settings)
                .verdict(for: focusedItem) == nil
        )

        // A drag tint names its visual's switch first, its own
        // part's second.
        settings.dragGhost.enabled = false
        settings.dragGhost.border = false
        gates = AdvancedColorsGates(settings: settings)
        #expect(
            gates.verdict(for: .borders(.dragGhostBorderColor))?.help
                == AdvancedColorsHelp.dragOff
        )
        #expect(
            gates.verdict(for: .borders(.dragDropZoneBorderColor))
                == nil
        )
        settings.dragGhost.enabled = true
        gates = AdvancedColorsGates(settings: settings)
        #expect(
            gates.verdict(for: .borders(.dragGhostBorderColor))?.help
                == AdvancedColorsHelp.dragBorderOff
        )
        #expect(
            gates.verdict(for: .borders(.dragGhostFillColor)) == nil
        )
    }

    /// A role group draws ONE link per page whose switch dims a
    /// row of it, in its rows' order, and none while every row
    /// draws (#1857, #1310) — a link per row would stack the
    /// same sentence under the card.
    @MainActor
    @Test("a role group links each page that dims one of its rows")
    func roleGroupLinksEachDimmingPage() {
        var settings = TilingSettings()
        settings.spaceBarStyle.enabled = true
        settings.spaceBarStyle.showFrontApp = true
        var gates = AdvancedColorsGates(settings: settings)
        #expect(
            gates.dimmedDestinations(
                of: ColorsRowOrder.accentAtRest
            ).isEmpty
        )
        #expect(
            gates.dimmedDestinations(
                of: ColorsRowOrder.secondAccentAtRest
            ).isEmpty
        )

        // Every bar off, the ring off and the ghost's border off:
        // both pages, once each, the shelf rows' first.
        settings.spaceBarStyle.enabled = false
        settings.monocle.appBar.enabled = false
        settings.scrolling.appBar.enabled = false
        settings.borderStyle.enabled = false
        settings.dragGhost.border = false
        gates = AdvancedColorsGates(settings: settings)
        #expect(!gates.shelfDraws)
        #expect(
            gates.dimmedDestinations(
                of: ColorsRowOrder.accentAtRest
            ) == [.bars, .gapsAndBorders]
        )

        // The drop zone off dims only the Second accent's drag
        // rows; with the bars back, Gaps & Borders alone.
        settings.spaceBarStyle.enabled = true
        settings.dragDropZone.enabled = false
        gates = AdvancedColorsGates(settings: settings)
        #expect(
            gates.dimmedDestinations(
                of: ColorsRowOrder.secondAccentAtRest
            ) == [.gapsAndBorders]
        )
    }
}
