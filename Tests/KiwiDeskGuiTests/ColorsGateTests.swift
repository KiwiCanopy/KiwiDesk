import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// How Colors & glass GREYS (#678 Phase 3) — split from
/// `ColorsCensusRenderTests` at the 350-line ceiling (§5, split
/// early). That suite pins which rows render where; this one
/// pins which of them are live, and why the page says what it
/// says when they are not.
///
/// The area is the first whose gates all live on ANOTHER page,
/// so the sentence a dimmed row is explained by is part of the
/// behaviour, not decoration.
@Suite("Colors & glass greying")
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
    }

    /// Colors & glass exempts no row from a container gate
    /// today. Pinned so that adding one is a conscious edit —
    /// the renderer already honors the flag as data
    /// (`ColorsAndGlassRows`), so the census is the only half a
    /// future exemption has to touch, and this is what asks
    /// whether it has an argument.
    @Test("no Colors & glass row escapes its container gate")
    func nothingIsExempt() {
        let rows = SettingKey.allCases.filter(\.isColourRow)
        #expect(!rows.isEmpty)
        #expect(
            rows.filter(\.placement.exemptFromContainerGate).isEmpty
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
        settings.spaceBarStyle.visibility = .hidden
        settings.monocle.appBar.visibility = .hidden
        settings.scrolling.appBar.visibility = .hidden
        // A hidden bar's shortcut still shows it, so its colours
        // never grey for its value (#761).
        let gates = ColorsAndGlassGates(settings: settings)
        for key in ColorsRowOrder.kiwishelfColorRows
        where key != .kiwishelf(.borderColor) {
            #expect(gates.verdict(for: key) == nil, "\(key.id)")
        }
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
        var gates = ColorsAndGlassGates(settings: settings)
        #expect(
            gates.verdict(for: unfocused)
                == ColorRowVerdict(
                    help: ColorsAndGlassHelp.borderOff,
                    link: .page(.gapsAndBorders)
                )
        )
        // Ring on, unfocused off: the row's own sentence (#1310).
        settings.borderStyle.enabled = true
        gates = ColorsAndGlassGates(settings: settings)
        #expect(
            gates.verdict(for: unfocused)?.link
                == .ownSentence(.gapsAndBorders)
        )
        settings.borderStyle.unfocusedEnabled = true
        #expect(
            ColorsAndGlassGates(settings: settings)
                .verdict(for: unfocused) == nil
        )

        // The focused-item row: with App icons and no front-app
        // name it takes its own sentence whatever the bars'
        // visibility (#761); Symbols draws.
        settings.spaceBarStyle.visibility = .hidden
        settings.monocle.appBar.visibility = .hidden
        settings.scrolling.appBar.visibility = .hidden
        settings.kiwishelf.iconSource = .appImage
        settings.spaceBarStyle.showFrontApp = false
        #expect(
            ColorsAndGlassGates(settings: settings)
                .verdict(for: focusedItem)
                == ColorRowVerdict(
                    help: ColorsAndGlassHelp.focusedItemHelp,
                    link: .ownSentence(.bars)
                )
        )
        settings.kiwishelf.iconSource = .appFont
        #expect(
            ColorsAndGlassGates(settings: settings)
                .verdict(for: focusedItem) == nil
        )

        // A drag tint names its visual's switch first, its own
        // part's second.
        settings.dragGhost.enabled = false
        settings.dragGhost.border = false
        gates = ColorsAndGlassGates(settings: settings)
        #expect(
            gates.verdict(for: .borders(.dragGhostBorderColor))?.help
                == ColorsAndGlassHelp.dragOff
        )
        #expect(
            gates.verdict(for: .borders(.dragDropZoneBorderColor))
                == nil
        )
        settings.dragGhost.enabled = true
        gates = ColorsAndGlassGates(settings: settings)
        #expect(
            gates.verdict(for: .borders(.dragGhostBorderColor))?.help
                == ColorsAndGlassHelp.dragBorderOff
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
        settings.spaceBarStyle.visibility = .always
        settings.spaceBarStyle.showFrontApp = true
        var gates = ColorsAndGlassGates(settings: settings)
        #expect(
            gates.dimmedDestinations(
                of: ColorsRowOrder.accentRows
            ).isEmpty
        )
        #expect(
            gates.dimmedDestinations(
                of: ColorsRowOrder.secondAccentRows
            ).isEmpty
        )

        // Every bar hidden, the ring off and the ghost's border
        // off: a hidden bar greys no colour (#761), so the ring's
        // page alone.
        settings.spaceBarStyle.visibility = .hidden
        settings.monocle.appBar.visibility = .hidden
        settings.scrolling.appBar.visibility = .hidden
        settings.borderStyle.enabled = false
        settings.dragGhost.border = false
        gates = ColorsAndGlassGates(settings: settings)
        #expect(
            gates.dimmedDestinations(
                of: ColorsRowOrder.accentRows
            ) == [.gapsAndBorders]
        )

        // The drop zone off dims only the Second accent's drag
        // rows; with the bars back, Gaps & Borders alone.
        settings.spaceBarStyle.visibility = .always
        settings.dragDropZone.enabled = false
        gates = ColorsAndGlassGates(settings: settings)
        #expect(
            gates.dimmedDestinations(
                of: ColorsRowOrder.secondAccentRows
            ) == [.gapsAndBorders]
        )

        // A page a row's own sentence already links takes no
        // second, vaguer link: App icons dim Focused window (its
        // own sentence, to Bars) and the front-app segment off
        // dims its indicator (a page link to Bars too).
        settings = TilingSettings()
        settings.spaceBarStyle.visibility = .always
        settings.kiwishelf.iconSource = .appImage
        settings.spaceBarStyle.showFrontApp = false
        gates = ColorsAndGlassGates(settings: settings)
        #expect(
            gates.needsOwnSentence(.spaceBar(.spaceBarFocusedItemColor))
        )
        #expect(
            gates.verdict(for: .spaceBar(.spaceBarFocusedHighlightColor))?
                .link == .page(.bars)
        )
        #expect(
            !gates.dimmedDestinations(
                of: ColorsRowOrder.secondAccentRows
            ).contains(.bars)
        )
    }
}
