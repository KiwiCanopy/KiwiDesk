import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The two colour areas render FROM the census (#678 Phase 3):
/// the census owns placement, `ColorsRowOrder` owns display
/// order. These pin the two together — every `.coloursAndMotion`
/// / `.advancedColours` census key appears in exactly the order
/// list its placement names, so a census row added, retiered or
/// moved without a renderer update is a red test, not a silently
/// missing control.
///
/// Set equality, not sequence: ORDER is the renderer's to own and
/// is deliberately not pinned here, exactly as in
/// `BarsCensusRenderTests`.
@Suite("Colours render ↔ census parity")
struct ColorsCensusRenderTests {
    private func censusRows(
        _ area: SettingsArea,
        _ container: SettingsContainer,
        _ tier: SettingTier
    ) -> Set<SettingKey> {
        Set(
            SettingKey.allCases.filter {
                $0.placement.area == area
                    && $0.placement.container == container
                    && $0.placement.tier == tier
            }
        )
    }

    private func pin(
        _ rendered: [SettingKey],
        _ area: SettingsArea,
        _ container: SettingsContainer,
        _ tier: SettingTier,
        _ what: Comment
    ) {
        #expect(
            Set(rendered) == censusRows(area, container, tier),
            what
        )
        #expect(rendered.count == Set(rendered).count, what)
    }

    // MARK: - Colours & Motion

    /// The shelf's at-rest half, hand-listed on purpose. Its
    /// four affordances are four different shapes — a tile grid,
    /// a link hanging under one tile, a trailing add-tile and a
    /// header button — so there is no order list to compare
    /// against, and a `ForEach` invented to create one would be
    /// a worse renderer rather than a census-driven one.
    ///
    /// A hand list is itself one more place to forget (the #520
    /// caveat), and it is taken here because the alternative is
    /// no net at all: a palette action added to the census with
    /// no shelf affordance would otherwise ship invisible.
    @Test("the palette shelf's at-rest actions are the census's")
    func palettesAtRest() {
        #expect(
            censusRows(.coloursAndMotion, .palettes, .atRest)
                == [
                    .colours(.paletteApply),
                    .colours(.paletteNeonGlowHint),
                    .colours(.paletteSave),
                    .colours(.paletteImport),
                ]
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

    /// The per-palette context menu. `.showMore` is the nearest
    /// true tier for a menu (not visible at rest, one interaction
    /// away) and the census says so in prose; what this pins is
    /// that the menu and the census agree on WHICH actions hide
    /// there — an action added to the menu with no census row
    /// reds here.
    @Test("the palette context menu is the census's show-more set")
    func palettesContextMenu() {
        pin(
            ColorsRowOrder.palettesContextMenu,
            .coloursAndMotion,
            .palettes,
            .showMore,
            "palette context menu"
        )
    }

    @Test("the Motion card's two tiers are the census's")
    func motionTiers() {
        pin(
            ColorsRowOrder.motionAtRest,
            .coloursAndMotion,
            .motion,
            .atRest,
            "motion at rest"
        )
        pin(
            ColorsRowOrder.motionMore,
            .coloursAndMotion,
            .motion,
            .showMore,
            "motion drawer"
        )
    }

    /// The area's render knows exactly two containers; a third
    /// would mount nowhere, so it must fail loud here rather than
    /// ship an unreachable row.
    @Test("Colours & Motion holds only palettes and motion")
    func coloursAndMotionContainers() {
        #expect(
            containers(of: .coloursAndMotion) == [.palettes, .motion]
        )
    }

    // MARK: - Advanced Colours

    @Test("the Borders group's rows are the census's")
    func bordersGroup() {
        pin(
            ColorsRowOrder.bordersAtRest,
            .advancedColours,
            .borders,
            .atRest,
            "border colors"
        )
        // No drawer: the group is small enough that hiding part
        // of it would move a decision rather than remove one.
        #expect(
            censusRows(.advancedColours, .borders, .showMore)
                .isEmpty
        )
    }

    /// One list per column, and the union is what the census
    /// must hold: the columns are what the renderer reads, so a
    /// combined list nothing renders would let a fifth drag tint
    /// ship invisible while this stayed green.
    @Test("the Drag group's rows are the census's")
    func dragGroup() {
        pin(
            ColorsRowOrder.dragGhostColumn
                + ColorsRowOrder.dragDropZoneColumn,
            .advancedColours,
            .dragAndDrop,
            .atRest,
            "drag colors"
        )
        #expect(
            censusRows(.advancedColours, .dragAndDrop, .showMore)
                .isEmpty
        )
    }

    @Test("the Space Bar group's two tiers are the census's")
    func spaceBarGroup() {
        pin(
            ColorsRowOrder.spaceBarAtRest,
            .advancedColours,
            .spaceBar,
            .atRest,
            "space bar accents"
        )
        pin(
            ColorsRowOrder.spaceBarMore,
            .advancedColours,
            .spaceBar,
            .showMore,
            "space bar drawer"
        )
    }

    @Test("the App Bar group's two tiers are the census's")
    func appBarGroup() {
        pin(
            ColorsRowOrder.appBarAtRest,
            .advancedColours,
            .appBar,
            .atRest,
            "app bar inline inks"
        )
        pin(
            ColorsRowOrder.appBarMore,
            .advancedColours,
            .appBar,
            .showMore,
            "app bar drawer"
        )
    }

    /// Four groups, matching the four things on screen. A fifth
    /// container placed in this area would render nowhere.
    @Test("Advanced Colours holds exactly the four groups")
    func advancedColoursContainers() {
        #expect(
            containers(of: .advancedColours)
                == [.borders, .dragAndDrop, .spaceBar, .appBar]
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
        let both = gates.dragHeaderHelp(ghost: true)
        #expect(
            both?.contains(AdvancedColorsHelp.dragBorderOff)
                == true
        )
        #expect(
            both?.contains(AdvancedColorsHelp.dragFillOff) == true
        )

        settings.dragGhost.border = true
        gates = AdvancedColorsGates(settings: settings)
        #expect(
            gates.dragHeaderHelp(ghost: true)
                == AdvancedColorsHelp.dragFillOff
        )
    }

    private func containers(
        of area: SettingsArea
    ) -> Set<SettingsContainer> {
        Set(
            SettingKey.allCases
                .filter { $0.placement.area == area }
                .compactMap { $0.placement.container }
        )
    }
}
