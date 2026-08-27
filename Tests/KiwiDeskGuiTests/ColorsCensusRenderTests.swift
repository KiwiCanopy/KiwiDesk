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

    // MARK: - Colours & Animations

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
    @Test("Colours & Animations holds only palettes and motion")
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
    ///
    /// Set equality over the union cannot see WHICH column a
    /// tint sits in — swapping one across renders the Ghost's
    /// Fill under the "Drop zone" heading, beside that column's
    /// preview and its `?`. `dragColumnsHoldTheirOwnVisual`
    /// below is the half that pins it.
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

    /// Each column holds its own visual's tints and no others,
    /// derived from the census row key rather than re-listed:
    /// the two columns render side by side, each with its own
    /// preview and its own gate, so a tint in the wrong one is
    /// labelled by the wrong visual and explained by the wrong
    /// switch.
    @Test("each drag column holds only its own visual's tints")
    func dragColumnsHoldTheirOwnVisual() {
        func isGhost(_ key: SettingKey) -> Bool {
            key.id.contains("dragGhost")
        }
        #expect(ColorsRowOrder.dragGhostColumn.allSatisfy(isGhost))
        #expect(
            ColorsRowOrder.dragDropZoneColumn.allSatisfy {
                !isGhost($0) && $0.id.contains("dragDropZone")
            }
        )
        // Vacuity: a renamed key shape would make both
        // `allSatisfy`s pass over nothing to check.
        #expect(!ColorsRowOrder.dragGhostColumn.isEmpty)
        #expect(!ColorsRowOrder.dragDropZoneColumn.isEmpty)
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
